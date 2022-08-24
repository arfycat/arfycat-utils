#!/bin/bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  umask 077

  user root "$@"

  lock
  log

  echo "$(date): $0 $@"
  cd /tmp || exit $?

  while :; do
    date
    if [[ -f /etc/init.d/rsyslog ]]; then
      service rsyslog status || service rsyslog restart || exit $?
    elif [[ -x /root/rsyslogd.sh ]]; then
      /root/rsyslogd.sh || exit $?
    fi
    
    if [[ -f /etc/init.d/cron ]]; then service cron status || service cron restart || exit $?; fi
    sleep 300
  done
  exit 0
}