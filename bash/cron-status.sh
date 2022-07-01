#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  HOST="$(basename "$0")"; HOST="${HOST%.*}"
  PW_FILE="${HOME}/.ssh/${HOST}.txt"

  cd /tmp || fail $? "Failed to change directory."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -pp)
        PASSPHRASE=
        shift
        ;;
      -pw)
        PASSWORD=
        shift
        ;;
      -pi)
        PIN=
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  TMP_LOG=; get_tmp_file TMP_LOG
  $(dirname "$(realpath "$0")")/status.sh > ${TMP_LOG} 2>&1
  RET=$?
  cat "${TMP_LOG}"

  SFTP_LOG=; get_tmp_file SFTP_LOG
  if [[ -r "${PW_FILE}" ]]; then
    if [[ -v PIN ]]; then
      echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -P "PIN" -f "${PW_FILE}" sftp ${HOST} >> ${SFTP_LOG} 2>&1
      _R=$?
    elif [[ -v PASSWORD ]]; then
      echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -f "${PW_FILE}" sftp ${HOST} >> ${SFTP_LOG} 2>&1
      _R=$?
    else
      echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -P "passphrase" -f "${PW_FILE}" sftp ${HOST} >> ${SFTP_LOG} 2>&1
      _R=$?
    fi
  else
    echo "PUT ${TMP_LOG} status.txt" | timeout 15s sftp ${HOST} >> ${SFTP_LOG} 2>&1
    _R=$?
  fi

  if [[ $_R -ne 0 ]]; then
    cat "${SFTP_LOG}"
  fi

  exit ${RET}
}