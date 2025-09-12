#!/usr/bin/env bash
set -o pipefail

SMARTCTL="$(which smartctl)"; _R=$?; [[ $_R -ne 0 ]] && exit $_R

_lsblk() {
  smartctl --scan | cut -d' ' -f1 | uniq | sort
  return $?
}

_smartctl() {
  [[ $# -eq 0 ]] && { echo "Usage: _smartctl <dev1> ... [devN]"; exit 255; }
  local RET=0
  local DEV="$1"

  if [[ -e "$DEV" ]] && smartctl -i "$DEV" >& /dev/null; then
    echo '--------------------------------------------------------------------------------'
    echo "${DEV}"
    echo '--------------------------------------------------------------------------------'
    ${SMARTCTL} -x "/dev/${DEV}" || RET=$?
    echo
  fi
  return ${RET}
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
