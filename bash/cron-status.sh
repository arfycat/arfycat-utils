#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  HOST="$(basename "$0")"; HOST="${HOST%.*}"
  ID_FILE="${HOME}/.ssh/${HOST}"
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

  TMP_LOG=; get_tmp_file TMP_LOG || fail $? "Failed to get temporary file."
  $(dirname "$(realpath "$0")")/status.sh >& "${TMP_LOG}"
  RET=$?
  cat "${TMP_LOG}"

  sftp-file() {
    local SFTP_LOG=; get_tmp_file SFTP_LOG || fail $? "Failed to create temporary file for SFTP."
    local RET=0
    if [[ -r "${PW_FILE}" ]]; then
      if [[ -v PIN ]]; then
        echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -P "PIN" -f "${PW_FILE}" sftp "${HOST}" &>> "${SFTP_LOG}"
        RET=$?
      elif [[ -v PASSWORD ]]; then
        echo "PUT ${TMP_LOG} status.txt" | timeout 15s sshpass -f "${PW_FILE}" sftp "${HOST}" &>> "${SFTP_LOG}"
        RET=$?
      else
        ssh-agent-add "${ID_FILE}" "${PW_FILE}" 20 && { echo "PUT ${TMP_LOG} status.txt" | timeout 15s sftp "-oBatchMode=yes" "${HOST}"; } &>> "${SFTP_LOG}"
        RET=$?
      fi
    else
      echo "PUT ${TMP_LOG} status.txt" | timeout 15s sftp "${HOST}" &>> "${SFTP_LOG}"
      RET=$?
    fi

    if [[ $RET -ne 0 ]]; then
      cat "${SFTP_LOG}"
    fi
    
    return $RET
  }
  
  sftp-file

  exit ${RET}
}