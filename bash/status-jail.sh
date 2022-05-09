#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
PATH="${PATH}:/usr/local/sbin:/usr/sbin:/sbin"
umask 077
RET=0

# top
TOP_FILE=; get_tmp_file TOP_FILE
(
  echo '> top' > ${TOP_FILE}
  if [[ -v LINUX ]]; then
    timeout 5s top -bn1 -w120 | tail -n+2 | head -n20 >> ${TOP_FILE} 2>&1
    timeout 5s top -bn1 -w120 -o%MEM | tail -n+6 | head -n16 >> ${TOP_FILE} 2>&1
    echo >> ${TOP_FILE}
  else
    timeout 5s top -btd1 | tail -n+2 >> ${TOP_FILE} 2>&1
    timeout 5s top -btd1 -ores | tail -n+9 >> ${TOP_FILE} 2>&1
  fi
) &
wait_pids_add "$!"

echo "$(date "+%Y-%m-%d") $(uptime)"
timeout 5s uname -v || RET=$?
echo

wait_pids

[[ -v TOP_FILE && -r "${TOP_FILE}" ]] && cat "${TOP_FILE}"

FSCADM="$(command -v fscadm)"
if [[ $? -eq 0 ]]; then
  echo '> fscadm'
  # fscadm doesn't seem too reliable, don't check exit code.
  ${FSCADM} status
  echo
fi

exit $RET
