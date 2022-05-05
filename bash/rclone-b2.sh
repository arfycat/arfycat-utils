#!/bin/bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
umask 077

[[ $# -eq 0 ]] && fail 1 "Usage: $0 <op> [args]"

HOME="$(get_home)"; [[ $? -ne 0 ]] && fail 1 "Failed to locate home directory."
if [[ ! -d "${HOME}" ]]; then fail 1 "Home directory does not exist: ${HOME}."; fi

lock
log

DIR="$(realpath "$(dirname "${0}")")"
SRCDIR="/"
DSTDIR="/"
REMOTE="b2"
REMOTE_FILTER="rclone-b2.filter"

if [[ -r "${HOME}/rclone-b2-bucket.txt" ]]; then
  BUCKET="$(cat "${HOME}/rclone-b2-bucket.txt")"; [[ $? -ne 0 ]] && fail 1 "Failed to read B2 bucket from file: ${HOME}/rclone-b2-bucket.txt"
elif [[ -r "/usr/local/etc/rclone-b2-bucket.txt" ]]; then
  BUCKET="$(cat "/usr/local/etc/rclone-b2-bucket.txt")"; [[ $? -ne 0 ]] && fail 1 "Failed to read B2 bucket from file: /usr/local/etc/rclone-b2-bucket.txt"
elif [[ -r "/etc/rclone-b2-bucket.txt" ]]; then
  BUCKET="$(cat "/etc/rclone-b2-bucket.txt")"; [[ $? -ne 0 ]] && fail 1 "Failed to read B2 bucket from file: /etc/rclone-b2-bucket.txt"
else
  fail 1 "Failed to locate rclone-b2-bucket.txt file."
fi
BUCKET_DIR=""

case "$1" in
  cleanup)
    if [[ $# -ge 2 ]]; then CLEANUP="$2"; else CLEANUP=""; fi
    "${DIR}/rclone.sh" -r "${REMOTE}" -d "${DSTDIR}/${CLEANUP}" -p "${BUCKET}${BUCKET_DIR}" cleanup
    exit $?
    ;;
  sync)
    "${DIR}/rclone.sh" -s "${SRCDIR}" -d "${DSTDIR}" -r "${REMOTE}" -p "${BUCKET}${BUCKET_DIR}" -f "rclone.filter" -f "${REMOTE_FILTER}" sync
    exit $?
    ;;
  lsr)
    if [[ $# -ge 2 ]]; then LS="$2"; else LS="/"; fi
    "${DIR}/rclone.sh" -d "${LS}" -r "${REMOTE}" -p "${BUCKET}${BUCKET_DIR}" lsr
    exit $?
    ;;
esac

fail 1 "Usage: $0 <op> [args]"
