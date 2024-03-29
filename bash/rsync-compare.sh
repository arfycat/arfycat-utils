#!/bin/bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  set -uo pipefail
  umask 077

  set -e
  NAME="$1"; shift
  HOME="$(get_home)"
  RSYNC_CMD="$(which rsync)"
  SYNC_KEY="${HOME}/.ssh/${NAME}"
  SYNC_HOST="${NAME}"
  EXCLUDE_FILE="${HOME}/${NAME}.exclude"
  set +e

  if [[ ! -r "${SYNC_KEY}" ]]; then
    fail $? "Failed to read sync key: ${SYNC_KEY}"
  elif [[ ! -r "${EXCLUDE_FILE}" ]]; then
    fail $? "Failed to read exclude file: ${EXCLUDE_FILE}"
  fi

  lock 0 "${NAME}"

  RSYNC="rsync -n --delete -crlziO --timeout=1800 --stderr=all --outbuf=l --exclude-from=${EXCLUDE_FILE}"
  if [[ -v DEBUG ]]; then RSYNC+=" --stats"; fi

  sync() {
    local SSH_KEY="$1"; shift
    local HOST="$1"; shift
    local LOCAL="$1"; shift
    local REMOTE="$1"; shift

    echo "${HOST}:${REMOTE} -> ${LOCAL}"
    if ! cd "${LOCAL}" && du -hd0 "${LOCAL}"; then
       return $?
    fi

    if [[ -f "${HOME}/.ssh/${NAME}.txt" && -f "${HOME}/.ssh/${NAME}" ]]; then
      ssh-agent-add "${HOME}/.ssh/${NAME}" "${HOME}/.ssh/${NAME}.txt" 10 || return $?
    fi

    ${RSYNC} "$@" "${HOST}:${REMOTE}/" "${LOCAL}/" \
      |& { grep -v -e "^$" \
                   -e "Number of created files: 0" \
                   -e "Number of deleted files: 0" \
                   -e "Number of regular files transferred: 0" \
                   -e "Total transferred file size: 0 bytes" \
                   -e "Literal data: 0 bytes" \
                   -e "Matched data: 0 bytes" \
                   -e " speedup is " || true; }; _R=$?
    ssh-add -qd "${HOME}/.ssh/${NAME}" >& /dev/null # This will possibly fail due to maximum key lifetime.
    echo
    return $_R
  }

  RET=0
  while read -r LINE; do
    IFS='|' read -a COLS <<< "${LINE}" || fail $? "Failed to parse line: ${LINE}"
    LOCAL="${COLS[0]}"
    REMOTE="${COLS[1]}"
    sync "${SYNC_KEY}" "${SYNC_HOST}" "${LOCAL}" "${REMOTE}" "$@" || RET=$?
  done < "${HOME}/${NAME}.dirs"
  exit $RET

  RET=0
  while read -r LINE; do
    IFS='|' read -a COLS <<< "${LINE}" || fail $? "Failed to parse line: ${LINE}"
    LOCAL="${COLS[0]}"
    REMOTE="${COLS[1]}"
    sync "${SYNC_KEY}" "${SYNC_HOST}" "${LOCAL}" "${REMOTE}" "$@" || RET=$?
  done < <(cat "${HOME}/${NAME}.dirs")
  exit $RET
}
