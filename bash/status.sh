#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  PATH="${PATH}:/usr/local/sbin:/usr/sbin:/sbin"

  RET=0

  if [[ $(uname) == "Linux" ]]; then
    LINUX=
  elif [[ $(uname) == "FreeBSD" ]]; then
    FREEBSD=
  fi

  echo "$(date "+%Y-%m-%d") $(uptime)"
  uname -v || RET=$?
  echo

  if UPRECORDS="$(which uprecords)"; then
    echo '> uprecords'
    ${UPRECORDS} -w -a || RET=$?
    echo
  fi

  if [[ -v FREEBSD ]]; then
    echo '> sysctl'
    echo "vfs.freevnodes: $(sysctl -n vfs.freevnodes) / $(sysctl -n kern.maxvnodes)"
    echo
  fi

  echo '> top'
  if [[ -v LINUX ]]; then
    timeout 5s top -bn1 -w120 | tail -n+2 | head -n20
    timeout 5s top -bn1 -w120 -o%MEM | tail -n+6 | head -n16
    echo
  else
    timeout 5s top -btd1 | tail -n+2
    timeout 5s top -btd1 -ores | tail -n+9
  fi

  if APCACCESS="$(which apcaccess)"; then
    echo '> apcaccess'
    "${APCACCESS}" || RET=$?
    echo
  fi

  if WG="$(which wg)"; then
    echo '> wg'
    "${WG}" || RET=$?
    echo
  fi

  if IFSTAT="$(which ifstat)"; then
    echo '> ifstat'
    timeout 40s ${IFSTAT} 30 1
    echo
  elif BWMNG="$(which bwm-ng)"; then
    echo '> bwm-ng'
    timeout 40s ${BWMNG} -c1 -t30000 -o plain | tail -n+2
    echo
  fi

  echo '> df'
  if [[ -v LINUX ]]; then
    timeout 30s df -hTx tmpfs || RET=$?
  else
    timeout 30s df -hTt nonullfs,linprocfs,devfs,fdescfs,linsysfs,procfs,zfs | sort || RET=$?
  fi
  echo

  if IOSTAT="$(which iostat)"; then

    echo '> iostat'
    if [[ -v LINUX ]]; then
      timeout 40s ${IOSTAT} -dhpy 30 1 | egrep -v "^$|loop|Linux"
    else
      timeout 40s ${IOSTAT} -tda -dzx -c1
    fi
    echo
  fi

  if [[ -x /home/chiafarmer/chia-blockchain/activate ]]; then
    echo '> chia farm summary'
    timeout 10s  su - chiafarmer -c "cd ~; source chia-blockchain/activate; chia farm summary"
    echo
  fi

  if [[ -x /home/flexfarmer/flexfarmer.sh ]]; then
    echo '> flexfarmer'
    timeout 10s /home/flexfarmer/flexfarmer.sh status || RET=$?
    [[ -r /home/flexfarmer/log/flexfarmer.log ]] && grep eligible /home/flexfarmer/log/flexfarmer.log | tail -10 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^.* elapsed=/elapsed=/'
    echo
  fi

  if [[ -x /home/phoenixminer/phoenixminer.sh ]]; then
    echo '> phoenixminer'
    timeout 10s /home/phoenixminer/phoenixminer.sh status || RET=$?
    [[ -r /home/phoenixminer/log/PhoenixMiner.log ]] && tail -1000 /home/phoenixminer/log/PhoenixMiner.log | grep 'Eth speed' | tail -1 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  if [[ -x /home/lolminer/lolminer.sh ]]; then
    echo '> lolminer'
    timeout 10s /home/lolminer/lolminer.sh status || RET=$?
    [[ -r /home/lolminer/log/lolMiner.log ]] && tail -100 /home/lolminer/log/lolMiner.log | grep 'Average speed' | tail -2 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  if [[ -x /home/raptoreum/cpuminer-gr-avx2.sh ]]; then
    echo '> cpuminer-gr-avx2'
    timeout 10s /home/raptoreum/cpuminer-gr-avx2.sh status || RET=$?
    [[ -r /home/raptoreum/log/cpuminer-gr-avx2.log ]] && grep -a "Hashrate" /home/raptoreum/log/cpuminer-gr-avx2.log | tail -10 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  if ZPOOL="$(which zpool)"; then
    echo '> zpool status'
    timeout 60s ${ZPOOL} status || RET=$?
    echo
  fi

  if ZFS="$(which zfs)"; then
    echo '> zfs list'
    timeout 60s ${ZFS} list || RET=$?
    echo
  fi

  if [[ -d /opt ]]; then
    ROCM_SMI="$(find /opt -wholename "/opt/rocm-*/bin/rocm-smi")"
    if [[ $? -eq 0 && "${ROCM_SMI}" != "" && -x "${ROCM_SMI}" ]]; then
      echo '> rocm-smi'
      timeout 10s su -m nobody -c "${ROCM_SMI}" 2>&1 | sed '/^[[:space:]]*$/d' || RET=$?
      echo
    fi
  fi

  if NVIDIA_SMI="$(which nvidia-smi)"; then
    echo '> nvidia-smi'
    timeout 10s su -m nobody -c "${NVIDIA_SMI}" || RET=$?
    echo
  fi

  if HWSTAT="$(which hwstat)"; then
    echo '> hwstat'
    timeout 10s ${HWSTAT} || RET=$?
    echo
  fi

  if SENSORS="$(which sensors)"; then
    echo '> sensors'
    timeout 10s ${SENSORS} || RET=$?
    #echo
  fi

  if MBMON="$(which mbmon)"; then
    timeout 10s ${MBMON} -c1 -r || RET=$?
    echo
  fi

  if IOCAGE="$(which iocage)"; then
    echo '> iocage list'
    timeout 60s ${IOCAGE} list -l || RET=$?
    echo
  fi
  
  if VM="$(which vm)"; then
    echo '> vm list'
    ${VM} list || RET=$?
    echo
  fi
  
  if DOCKER="$(which docker)"; then
    echo '> docker compose ls'
    ${DOCKER} compose ls || RET=$?
    echo
  fi

  if VIRSH="$(which virsh)"; then
    echo '> virsh list'
    ${VIRSH} list || RET=$?
  fi

  LSUSB="$(which lsusb)"
  if [[ $? -eq 0 && -e /sys/bus/usb/devices ]]; then
    echo '> lsusb'
    timeout 10s ${LSUSB} -t || RET=$?
    echo
  fi

  LSBLK="$(which lsblk)"
  if [[ $? -eq 0 && -e /sys/dev/block ]]; then
    echo '> lsblk'
    timeout 10s ${LSBLK} || RET=$?
    echo
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
          timeout 10s ${SMARTCTL} -iAH -l error ${DEV} | egrep -v '^(smartctl |Copyright |Host [a-zA-Z]+ Commands|Controller Busy Time|=== START)'
        fi
      done < <(geom disk list | egrep '^Geom name:' | awk '{print $3}')
    else
      while read -r DEV; do
        echo "${DEV}:"
        timeout 10s ${SMARTCTL} -iAH -l error /dev/${DEV} | egrep -v '^(smartctl |Copyright |Host [a-zA-Z]+ Commands|Controller Busy Time|=== START)'
      done < <(timeout 5s lsblk -nal -o name,type 2>/dev/null | grep " disk" | cut -d' ' -f1)
    fi
  fi

  exit $RET
}
