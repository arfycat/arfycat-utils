#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  set -o pipefail

  # Script must be sourced.
  if [[ "$BASH_SOURCE" == "$0" ]]; then fail 1 "$0 must be sourced."; fi

  SCRIPT="$(realpath "$0")"; _R=$?; [[ $_R -ne 0 ]] && fail $_R "Failed: realpath $0"
  DIR="$(dirname "${SCRIPT}")"; _R=$?; [[ $_R -ne 0 ]] && fail $_R "Failed: dirname $SCRIPT"
  BASENAME="$(basename $0)"; _R=$?; [[ $_R -ne 0 ]] && fail $_R "ut: basename $0"
  NAME="${BASENAME%.*}"

  RSYNC_REMOTE_HOST="$(ssh -G "${NAME}" | awk '/^hostname / { print $2 }')"; _R=$?; [[ $_R -ne 0 ]] && fail $_R "Failed to determine remote hostname from SSH config."
  RSYNC="$(which rsync)"; _R=$?; [[ $_R -ne 0 ]] && fail $_R "Failed to locate rsync."
  RSYNC_EXCLUDE_FILE="${DIR}/${NAME}-exclude.txt"
  RSYNC_FROM_FILE="${DIR}/${NAME}-from.txt"
  RSYNC_KEY="$(ssh -G "${NAME}" | awk '/^identityfile / { print $2 }')"; [[ $? -ne 0 ]] && fail 1 "Failed to determine identity file from SSH config."
  OPTS="--chmod=D750,F640 --delete --delete-excluded --delete-after -rltzRi --compress-choice=lz4 --open-noatime --safe-links --timeout=1200 --outbuf=L"
  export RSYNC_RSH="sshpass -P '${RSYNC_KEY}' -f ${RSYNC_KEY}.txt ssh -T"

  if [[ -r "${RSYNC_EXCLUDE_FILE}" ]]; then
    OPTS+=" --exclude-from=${RSYNC_EXCLUDE_FILE}"
  fi

  if [[ -r "${RSYNC_FROM_FILE}" ]]; then
    OPTS+=" --files-from=${RSYNC_FROM_FILE}"
  fi

  if [[ "${RSYNC_REMOTE_HOST}" == "${NAME}" ]]; then
    fail 1 "Failed to lookup hostname in SSH config."
  fi

  lock 0 "${NAME}"

  sync() {
    if [[ $# -lt 2 ]]; then
      echo "Incorrect arguments: sync <source> <destination> [working directory] [rsync args]"
      return 1
    fi

    SRC="$1"; shift
    DST="$1"; shift
    
    if [[ $# -gt 0 ]]; then
      local DIR="$1"; shift
    else
      local DIR="/tmp"
    fi
    
    if [[ ! -d "${DIR}" ]]; then
      echo "Directory does not exist: ${DIR}"
      return 1
    fi

    cmd "${RSYNC}" ${OPTS} "$@" "${SRC}" "${DST}" 2>&1 | { grep --line-buffered -v "Pseudo-terminal will not be allocated because stdin is not a terminal."; true; }
    return $?
  }
  
  return 0
}