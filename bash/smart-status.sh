#!/usr/bin/env bash
set -o pipefail

SMARTCTL="$(which smartctl)"
if [[ $? -ne 0 ]]; then exit 1; fi

_lsblk() {
  if [[ "$(uname)" =~ ^Linux.* ]]; then
    lsblk -Sno name | sort
    return $?
  else
    geom disk list | egrep '^Geom name:' | awk '{print $3}' | sed 's/^nvd/nvme/g' | sort
    return $?
  fi
}

RET=0
while read -r DEV; do
  echo '--------------------------------------------------------------------------------'
  echo "${DEV}"
  echo '--------------------------------------------------------------------------------'
  ${SMARTCTL} -x "/dev/${DEV}" || RET=$?
  echo
done < <(_lsblk)
exit ${RET}
