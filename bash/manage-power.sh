#!/bin/bash
{
  source /usr/share/arfycat/bashutils.sh || { echo Failed to source arfycat/bashutils.sh; exit 255; }
  
  if [[ ! -r /sys/class/power_supply/ADP1/online ]]; then
    fail 1 "Cannot read power supply online status: /sys/class/power_supply/ADP1/online"
  fi

  lock

  suspend() {
    echo "$(date): Detected power loss, suspending."
    if [[ -x "/etc/arfycat/suspend" ]]; then
      /etc/arfycat/suspend
    fi

    sync
    sleep 5
    sync

    rtcwake -m mem -s 300 > /dev/null
    sleep 5
    rtcwake -m no -s 900 > /dev/null
  }

  resume() {
    echo "$(date): Resume after suspend."
    lsusb -v > /dev/null
    sleep 5

    if [[ -x "/etc/arfycat/resume" ]]; then
      /etc/arfycat/resume
    fi
  }

  while :; do
    # Lists USB devices, also seems to trigger rescanning
    lsusb -v > /dev/null
    sleep 5

    if [[ $(cat /sys/class/power_supply/ADP1/online) != "1" ]]; then
      SUSPENDED=
      suspend
    else
      break
    fi
  done

  if [[ -v SUSPENDED ]]; then
    resume
  fi

  rtcwake -m no -s 900 > /dev/null
  exit $?
}