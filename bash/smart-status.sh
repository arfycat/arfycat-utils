#!/usr/bin/env bash
set -o pipefail

SMARTCTL="$(which smartctl)"; _R=$?; [[ $_R -ne 0 ]] && exit $_R

_lsblk() {
  if [[ "$(uname)" =~ ^Linux.* ]]; then
    lsblk -Sno name | sort
    return $?
  else
    geom disk list | egrep '^Geom name:' | awk '{print $3}' | sed 's/^nvd/nvme/g' | sort
    return $?
  fi
}

_smartctl() {
  local DEV="$1"
  echo '--------------------------------------------------------------------------------'
  echo "${DEV}"
  echo '--------------------------------------------------------------------------------'
  ${SMARTCTL} -x "/dev/${DEV}" || RET=$?
  echo
}

RET=0
if [[ $# -gt 0 ]]; then
  while [[ $# -ne 0 ]]; do
    _smartctl "$1" || RET=$?
    shift
  done
else
  while read -r DEV; do
    _smartctl "${DEV}" || RET=$?
  done < <(_lsblk)
fi

exit ${RET}
