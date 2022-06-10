#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  set -o pipefail
  umask 077

  HOME="$(get_home)"; [[ $? -ne 0 ]] && fail 1 "Failed to locate home directory."
  if [[ ! -d "${HOME}" ]]; then fail 1 "Home directory does not exist: ${HOME}."; fi

  ARGS="$@"
  SCRIPT=$(basename $0)

  FILTER=
  SRC="/"
  RCLONE_ARGS=

  while [[ $# -gt 0 ]]; do
    case $1 in
      -r)
        REMOTE="$2"
        shift
        shift
        ;;
      -p)
        PREFIX="$2"
        shift
        shift
        ;;
      -f)
        FILTER_FILE="${2}"
        if [[ ! -r "${FILTER_FILE}" ]]; then
          if [[ -r "${HOME}/${FILTER_FILE}" ]]; then
            FILTER_FILE="${HOME}/${FILTER_FILE}"
          elif [[ -r "/usr/local/etc/${FILTER_FILE}" ]]; then
            FILTER_FILE="/usr/local/etc/${FILTER_FILE}"
          elif [[ -r "/etc/${FILTER_FILE}" ]]; then
            FILTER_FILE="/etc/${FILTER_FILE}"
          else
            fail 1 "Failed to read filter file: ${FILTER_FILE}"
          fi
        else
          FILTER_FILE="$(realpath "${FILTER_FILE}")"
        fi
        FILTER="${FILTER} --filter-from ${FILTER_FILE}"
        unset -v FILTER_FILE
        shift
        shift
        ;;
      -s)
        SRC="${2}"
        if [ ! -x "${SRC}" ]; then fail 1 "Failed to locate source: ${SRC}"; fi
        shift
        shift
        ;;
      -d)
        DST="${2}"
        shift
        shift
        ;;
      --dry-run)
        RCLONE_ARGS="${RCLONE_ARGS} --dry-run"
        shift
        ;;
      -*|--*)
        fail 1 "Unknown option: $1"
        ;;
      cleanup)
        OP="${1}"
        shift
        break
        ;;
      sync)
        OP="${1}"
        shift
        break
        ;;
      lsr)
        OP="${1}"
        shift
        break
        ;;
      *)
        fail 1 "Invalid argument: $1"
        ;;
    esac
  done
  if [[ ! -v OP ]]; then OP="sync"; fi

  if [[ ! -v REMOTE || "${REMOTE}" == "" ]]; then
    fail 1 "Missing required remote argument."
  fi

  if [[ ! -v PREFIX ]]; then
    PREFIX=
  fi

  check_remote() {
    for i in {0..5}; do
      rclone listremotes | egrep -q "^${1}:" && return 0
      sleep 5
    done
    return 1
  }
  check_remote "${REMOTE}" || fail 1 "Remote does not exist: ${REMOTE}"

  lock 3600 "${REMOTE}"
  log "${REMOTE}-${OP}"

  TMPLOG=; get_tmp_file TMPLOG

  rclone-cmd() {
    local HEADER="$1"
    shift
   
    local DIR="$1"
    shift

    if ! cd ${DIR} &> /dev/null; then
      echo "${HEADER}"
      echo "Failed to change directory: ${DIR}"
      return 1
    fi

    [[ -v DEBUG ]] && echo "> rclone" "$@"
    rclone "$@" 2>&1 | { grep --line-buffered -Ev "^$|Making map for --track-renames|Finished making map for --track-renames|Waiting for checks to finish|Waiting for renames to finish|Waiting for transfers to finish|Waiting for deletions to finish|There was nothing to transfer" || true; } > ${TMPLOG}
    RET=$?
    [[ $RET -ne 0 || -s $TMPLOG ]] && { echo "${HEADER}"; cat $TMPLOG; echo; }
    [[ -v DEBUG ]] && echo "= ${RET}"
    echo : > $TMPLOG
    return $RET
  }

  rclone-cleanup() {
    rclone-cmd "Cleanup ${REMOTE}:${PREFIX}${DST}" "$HOME" cleanup $RCLONE_ARGS --fast-list "$REMOTE:$PREFIX"
    return $?
  }

  rclone-sync() {
    if [[ ! -v DST ]]; then local DST="${SRC}"; fi

    if [[ ! -v DEBUG ]]; then
      local DEBUG_ARGS="--stats-log-level DEBUG"
    else
      local DEBUG_ARGS=
    fi

    rclone-cmd "${SRC} -> ${REMOTE}:${PREFIX}${DST}" ${HOME} sync ${RCLONE_ARGS} ${FILTER} --exclude-if-present .ignore --delete-excluded --create-empty-src-dirs --track-renames --fast-list -lc --transfers 16 --buffer-size 4M -v --stats-log-level DEBUG --stats-one-line "$@" "${SRC}" "${REMOTE}:${PREFIX}${DST}"
    return $?
  }

  rclone-lsr() {
    if [[ ! -v DST ]]; then local DST="/"; fi

    rclone-cmd "ls ${REMOTE}:${PREFIX}${DST}" ${HOME} ls ${RCLONE_ARGS} --fast-list "${REMOTE}:${PREFIX}${DST}"
    return $?
  }

  case "${OP}" in
    cleanup)
      rclone-cleanup "$@"
      exit $?
      ;;
    sync)
      rclone-sync "$@"
      exit $?
      ;;
    lsr)
      rclone-lsr "$@"
      exit $?
      ;;
    *)
      fail 1 "Invalid operation: ${OP}"
      ;;
  esac
  exit 1
}