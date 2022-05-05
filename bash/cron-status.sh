#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
HOST="$(basename "$0")"
ID="$(get_home)/.ssh/id_ed25519"

TMP_LOG=; get_tmp_file TMP_LOG
$(dirname "$(realpath "$0")")/status.sh > ${TMP_LOG} 2>&1
RET=$?
cat "${TMP_LOG}"

SFTP_LOG=; get_tmp_file SFTP_LOG
if ! echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -P "passphrase" -f "${ID}.txt" sftp -i "${ID}" ${HOST} >> ${SFTP_LOG} 2>&1; then
  cat "${SFTP_LOG}"
  fail 1 "Failed to upload status."
fi

exit ${RET}
