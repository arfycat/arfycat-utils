#!/bin/bash
{
  if ! PATH="${PATH}:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  umask 077

  user root "$@"

  lock
  log

  echo "$(date): $0 $@"
  cd /tmp || exit $?

  while :; do
    date
    if [[ -r /etc/wsl-services ]]; then
      while read SERVICE; do
        if [[ -x "/etc/init.d/${SERVICE}" ]]; then
          service "${SERVICE}" status || service "${SERVICE}" restart || exit $?
        elif [[ -x "/usr/share/arfycat/${SERVICE}.sh" ]]; then
          "/usr/share/arfycat/${SERVICE}.sh" || exit $?
        else
          fail 1 "Failed to locate script for service: ${SERVICE}"
        fi
      done < /etc/wsl-services
      WSL_SERVICES="$(cat /etc/wsl-services)"
    fi
    sleep 293
  done
  exit 0
}