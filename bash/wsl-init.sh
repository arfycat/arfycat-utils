#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
umask 077

lock
log

echo "$(date): $0 $@"
cd /tmp || exit $?

while :; do
  date
  service rsyslog status || service rsyslog restart || exit $?
  service cron status || service cron restart || exit $?
  sleep 360
done
