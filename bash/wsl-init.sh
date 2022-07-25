#!/bin/bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  umask 077

  lock
  log

  echo "$(date): $0 $@"
  cd /tmp || exit $?

  while :; do
    date
    if [[ -f /etc/init.d/rsyslog ]]; then service rsyslog status || service rsyslog restart || exit $?; fi
    if [[ -f /etc/init.d/cron ]]; then service cron status || service cron restart || exit $?; fi
    sleep 600
  done
  exit 0
}