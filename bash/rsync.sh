#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
set -o pipefail
umask 077

if [ ! -d "${HOME}" ]; then
  fail 1 "Home directory does not exist: ${HOME}."
fi

SCRIPT="$(basename $0)"; [[ $? -ne 0 ]] && fail 1 "Failed to get basename of script: $0"
RSYNC_REMOTE_HOST="$(ssh -G "${SCRIPT}" | awk '/^hostname / { print $2 }')"; [[ $? -ne 0 ]] && fail 1 "Failed to determine remote hostname from SSH config."
RSYNC="$(which rsync)"; [[ $? -ne 0 ]] && fail 1 "Failed to locate rsync."
RSYNC_EXCLUDE_FILE="$(realpath $0)-exclude.txt"
RSYNC_KEY="$(ssh -G "${SCRIPT}" | awk '/^identityfile / { print $2 }')"; [[ $? -ne 0 ]] && fail 1 "Failed to determine identity file from SSH config."
OPTS="--exclude-from=${RSYNC_EXCLUDE_FILE} --chmod=u+Xrw,g+Xr,g-w,o-Xrw --delete --delete-excluded -azltRi --safe-links --timeout=3600"
SSH_CMD="sshpass -P '${RSYNC_KEY}' -f ${RSYNC_KEY}.txt ssh -T"

if [ ! -r "${RSYNC_EXCLUDE_FILE}" ]; then
  fail 1 "Cannot read exclude file: ${RSYNC_EXCLUDE_FILE}."
fi

if [ "${RSYNC_REMOTE_HOST}" == "${SCRIPT}" ]; then
  fail 1 "Failed to lookup hostname in SSH config."
fi

lock 3600 "${RSYNC_REMOTE_HOST}"

cmd() {
  if ! cd ${1}; then
    return 1
  fi

  shift
  "$@"
  RET=$?
  return ${RET}
}

sync() {
  if [[ $# -ne 2 ]]; then
    echo "Incorrect arguments: sync <source> <destination>"
    return 1
  fi

  SRC="$1"
  DST="$2"

  cmd /tmp "${RSYNC}" ${OPTS} --rsh "${SSH_CMD}" "${SRC}" "${DST}"
  return $?
}
