#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  PATH="${PATH}:/usr/local/sbin:/usr/sbin:/sbin"

  RET=0

  cmd() {
    local _RET=-1

    LOG_PRE="$1"
    shift

    TIMEOUT="$1"
    shift

    EXE="$1"
    shift

    local EXE_PATH="$(which "$EXE" 2> /dev/null)"
    if [[ "$EXE_PATH" != "" ]]; then
       _RET=0

      if [[ "$LOG_PRE" != "" ]]; then
        echo "> $LOG_PRE"
      fi

      if [[ $TIMEOUT != 0 ]]; then
        timeout ${TIMEOUT}s "$EXE_PATH" "$@" || _RET=1
      else
        "$EXE_PATH" "$@" || _RET=1
      fi
    fi

    if [[ $RET == 1 ]]; then
      echo "Command Failed: $EXE_PATH $@"
    fi

    if [[ $_RET == 1 ]]; then
      RET=$_RET
    fi

    if [[ $_RET != -1 ]]; then
      echo
    fi

    return $_RET
  }

  if [[ $(uname) == "Linux" ]]; then
    LINUX=
  elif [[ $(uname) == "FreeBSD" ]]; then
    FREEBSD=
  fi

  echo "$(date "+%Y-%m-%d") $(uptime)"
  cmd uname 0 uname -v

  cmd uprecords 0 uprecords -w -a

  if [[ -v FREEBSD ]]; then
    echo '> sysctl'
    echo "vfs.freevnodes: $(sysctl -n vfs.freevnodes) / $(sysctl -n kern.maxvnodes)"
    echo
  fi

  echo '> top'
  if [[ -v LINUX ]]; then
    top -bn1 -w120 | tail -n+2 | head -n20
    top -bn1 -w120 -o%MEM | tail -n+6 | head -n16
    echo
  else
    top -btd1 | tail -n+2
    top -btd1 -ores | tail -n+9
  fi

  cmd apcaccess 0 apcaccess
  cmd wg 0 wg

  if IFSTAT="$(which ifstat)"; then
    cmd ifstat 0 "$IFSTAT" 30 1
  elif BWMNG="$(which bwm-ng)"; then
    echo '> bwm-ng'
    "$BWMNG" -c1 -t30000 -o plain | tail -n+2
    echo
  fi

  if [[ -v LINUX ]]; then
    cmd df 0 df -hTx tmpfs
  else
    echo '> df'
    df -hTt nonullfs,linprocfs,devfs,fdescfs,linsysfs,procfs,zfs | sort || RET=$?
    echo
  fi

  if IOSTAT="$(which iostat)"; then
    if [[ -v LINUX ]]; then
      echo '> iostat'
      "$IOSTAT" -dhpy 30 1 | egrep -v "^$|loop|Linux"
      echo
    else
      cmd iostat 0 "$IOSTAT" -tda -dzx -c1
    fi
  fi

  if [[ -x /home/chiafarmer/chia-blockchain/activate ]]; then
    echo '> chia farm summary'
    su - chiafarmer -c "cd ~; source chia-blockchain/activate; chia farm summary"
    echo
  fi

  cmd 'zpool status' 0 zpool status
  cmd 'zfs list' 0 zfs list

  if [[ -v LINUX && -d /opt ]]; then
    ROCM_SMI="$(find /opt -wholename "/opt/rocm-*/bin/rocm-smi")"
    if [[ $? -eq 0 && "${ROCM_SMI}" != "" && -x "${ROCM_SMI}" ]]; then
      echo '> rocm-smi'
      timeout 20s su -m nobody -c "${ROCM_SMI}" 2>&1 | sed '/^[[:space:]]*$/d' || RET=$?
      echo
    fi
  fi

  if NVIDIA_SMI="$(which nvidia-smi)"; then
    echo '> nvidia-smi'
    timeout 20s su -m nobody -c "${NVIDIA_SMI}" || RET=$?
    echo
  fi

  cmd hwstat 0 hwstat
  cmd sensors 0 sensors
  cmd mbmon 0 mbmon -c1 -r
  cmd 'iocage list' 0 iocage list -l 
  cmd 'vm list' 0 vm list
  cmd 'docker compose ls' 0 docker compose ls
  cmd 'virsh list' 0 virsh list
  if [[ -e /sys/bus/usb/devices ]]; then
    cmd lsusb 0 lsusb -t
  fi

  if [[ -e /sys/dev/block ]]; then
    cmd lsblk 0 lsblk
  fi

  if SMARTCTL="$(which smartctl)"; then
    echo '> smartctl'
    if [[ -v FREEBSD ]]; then
      while read -r DEV; do
        # On FreeBSD, smartctl only works on /dev/nvme# devices.
        DEV="${DEV/nda/nvme}"
        DEV="${DEV/nvd/vnme}"
        DEV="/dev/${DEV}"

        if [[ -e "${DEV}" ]]; then
          echo "${DEV}:"
          timeout 20s ${SMARTCTL} -iAH -l error ${DEV} | egrep -v '^(smartctl |Copyright |Host [a-zA-Z]+ Commands|Controller Busy Time|=== START)'
        fi
      done < <(geom disk list | egrep '^Geom name:' | awk '{print $3}')
    else
      while read -r DEV; do
        echo "${DEV}:"
        timeout 20s ${SMARTCTL} -iAH -l error /dev/${DEV} | egrep -v '^(smartctl |Copyright |Host [a-zA-Z]+ Commands|Controller Busy Time|=== START)'
      done < <(timeout 20s lsblk -nal -o name,type 2>/dev/null | grep " disk" | cut -d' ' -f1)
    fi
  fi

  exit $RET
}
