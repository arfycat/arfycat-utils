#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
umask 077

DATE="$(TZ=UTC date "+%Y-%m-%d_%H:%M:%S")"; [[ $? -ne 0 ]] && fail 1 "Failed to get current date."

if [[ $# -ge 1 ]]; then
  SNAP_PREFIX="${1}-"
else
  SNAP_PREFIX=
fi

RET=0
while read -r ZFS; do
  if [[ "$(zfs get -Ho value local:boot_snapshot "${ZFS}")" == "0" ]]; then
    echo "x zfs snapshot ${ZFS}@${SNAP_PREFIX}${DATE}"
  else
    echo "> zfs snapshot ${ZFS}@${SNAP_PREFIX}${DATE}"
    zfs snapshot "${ZFS}@${SNAP_PREFIX}${DATE}" || RET=$?
  fi
done < <(zfs list -H -oname | sort)
exit ${RET}
