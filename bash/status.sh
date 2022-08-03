#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  PATH="${PATH}:/usr/local/sbin:/usr/sbin:/sbin"

  if [[ $(uname) == "Linux" ]]; then
    LINUX=
  elif [[ $(uname) == "FreeBSD" ]]; then
    FREEBSD=
  fi

  # top
  TOP_FILE=; get_tmp_file TOP_FILE
  (
    echo '> top' > ${TOP_FILE}
    if [[ -v LINUX ]]; then
      timeout 5s top -bn1 -w120 | tail -n+2 | head -n20 >> ${TOP_FILE} 2>&1
      timeout 5s top -bn1 -w120 -o%MEM | tail -n+6 | head -n16 >> ${TOP_FILE} 2>&1
      echo >> ${TOP_FILE}
    else
      timeout 5s top -btd1 | tail -n+2 >> ${TOP_FILE} 2>&1
      timeout 5s top -btd1 -ores | tail -n+9 >> ${TOP_FILE} 2>&1
    fi
  ) &
  wait_pids_add "$!"

  # ifstat
  IFSTAT="$(which ifstat)"
  if [[ $? -eq 0 ]]; then
    IFSTAT_FILE=; get_tmp_file IFSTAT_FILE
    {
      echo '> ifstat' > "${IFSTAT_FILE}"
      timeout 40s ${IFSTAT} 30 1 >> "${IFSTAT_FILE}" 2>&1
      echo >> "${IFSTAT_FILE}"
    } &
    wait_pids_add "$!"
  fi

  # bwm-ng
  BWMNG="$(which bwm-ng)"
  if [[ $? -eq 0 ]]; then
    BWMNG_FILE=; get_tmp_file BWMNG_FILE
    (
      echo '> bwm-ng' > ${BWMNG_FILE}
      timeout 40s ${BWMNG} -c1 -t30000 -o plain | tail -n+2 >> ${BWMNG_FILE} 2>&1
      echo >> ${BWMNG_FILE}
    ) &
    wait_pids_add "$!"
  fi

  # iostat
  IOSTAT="$(which iostat)"
  if [[ $? -eq 0 ]]; then
    IOSTAT_FILE=; get_tmp_file IOSTAT_FILE
    (
      echo '> iostat' > ${IOSTAT_FILE}
      if [[ -v LINUX ]]; then
        timeout 40s ${IOSTAT} -dhpy 30 1 | egrep -v "^$|loop|Linux" >> ${IOSTAT_FILE} 2>&1
      else
        timeout 40s ${IOSTAT} -tda -dzx -c1 >> ${IOSTAT_FILE} 2>&1
      fi
      echo >> ${IOSTAT_FILE}
    ) &
    wait_pids_add "$!"
  fi

  #/usr/bin/w
  #echo

  wait_pids

  echo $(date "+%Y-%m-%d") $(uptime)
  uname -v
  echo

  UPRECORDS="$(which uprecords)"
  if [[ $? -eq 0 ]]; then
    echo '> uprecords'
    ${UPRECORDS} -w -a
    echo
  fi

  if [[ -v FREEBSD ]]; then
    echo '> sysctl'
    echo "vfs.numvnodes: $(sysctl -n vfs.numvnodes) / $(sysctl -n kern.maxvnodes)"
    echo
  fi

  [[ -v TOP_FILE && -r "${TOP_FILE}" ]] && cat "${TOP_FILE}"

  APCACCESS="$(which apcaccess)"
  if [[ $? -eq 0 ]]; then
    ${APCACCESS}
    echo
  fi

  WG="$(which wg)"
  if [[ $? -eq 0 ]]; then
    echo '> wg'
    "${WG}"
    echo
  fi

  if [[ -v IFSTAT_FILE && -r "${IFSTAT_FILE}" ]]; then cat "${IFSTAT_FILE}";
  elif [[ -v BWMNG_FILE && -r "${BWMNG_FILE}" ]]; then cat "${BWMNG_FILE}"; fi

  echo '> df'
  if [[ -v LINUX ]]; then
    timeout 10s df -hTx tmpfs
  else
    timeout 10s df -hTt nonullfs,linprocfs,devfs,tmpfs,fdescfs,linsysfs,procfs,zfs
  fi
  echo

  [[ -v IOSTAT_FILE && -r "${IOSTAT_FILE}" ]] && cat "${IOSTAT_FILE}"

  if [[ -x /home/chiafarmer/chia-blockchain/activate ]]; then
    echo '> chia farm summary'
    timeout 10s  su - chiafarmer -c "cd ~; source chia-blockchain/activate; chia farm summary"
    echo
  fi

  if [[ -x /home/flexfarmer/flexfarmer.sh ]]; then
    echo '> flexfarmer'
    timeout 10s /home/flexfarmer/flexfarmer.sh status
    [[ -r /home/flexfarmer/log/flexfarmer.log ]] && grep eligible /home/flexfarmer/log/flexfarmer.log | tail -10 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^.* elapsed=/elapsed=/'
    echo
  fi

  if [[ -x /home/phoenixminer/phoenixminer.sh ]]; then
    echo '> phoenixminer'
    timeout 10s /home/phoenixminer/phoenixminer.sh status
    [[ -r /home/phoenixminer/log/PhoenixMiner.log ]] && tail -1000 /home/phoenixminer/log/PhoenixMiner.log | grep 'Eth speed' | tail -1 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  if [[ -x /home/lolminer/lolminer.sh ]]; then
    echo '> lolminer'
    timeout 10s /home/lolminer/lolminer.sh status
    [[ -r /home/lolminer/log/lolMiner.log ]] && tail -100 /home/lolminer/log/lolMiner.log | grep 'Average speed' | tail -2 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  if [[ -x /home/raptoreum/cpuminer-gr-avx2.sh ]]; then
    echo '> cpuminer-gr-avx2'
    timeout 10s /home/raptoreum/cpuminer-gr-avx2.sh status
    [[ -r /home/raptoreum/log/cpuminer-gr-avx2.log ]] && grep -a "Hashrate" /home/raptoreum/log/cpuminer-gr-avx2.log | tail -10 | sed 's/\x1b\[[0-9;]*m//g'
    echo
  fi

  ZPOOL="$(which zpool)"
  if [[ $? -eq 0 ]]; then
    echo '> zpool status'
    timeout 10s ${ZPOOL} status
    echo
  fi

  ZFS="$(which zfs)"
  if [[ $? -eq 0 ]]; then
    echo '> zfs list'
    timeout 10s ${ZFS} list
    echo
  fi

  if [[ -d /opt ]]; then
    ROCM_SMI="$(find /opt -wholename "/opt/rocm-*/bin/rocm-smi")"
    if [[ $? -eq 0 && "${ROCM_SMI}" != "" && -x "${ROCM_SMI}" ]]; then
      echo '> rocm-smi'
      timeout 10s su -m nobody -c "${ROCM_SMI}" 2>&1 | sed '/^[[:space:]]*$/d'
      echo
    fi
  fi

  NVIDIA_SMI="$(which nvidia-smi)"
  if [ $? -eq 0 ]; then
    echo '> nvidia-smi'
    timeout 10s su -m nobody -c "${NVIDIA_SMI}"
    echo
  fi

  HWSTAT="$(which hwstat)"
  if [[ $? -eq 0 ]]; then
    echo '> hwstat'
    timeout 10s ${HWSTAT}
    echo
  fi

  SENSORS="$(which sensors)"
  if [[ $? -eq 0 ]]; then
    echo '> sensors'
    timeout 10s ${SENSORS}
    #echo
  fi

  MBMON="$(which mbmon)"
  if [[ $? -eq 0 ]]; then
    timeout 10s ${MBMON} -c1 -r
    echo
  fi

  LSUSB="$(which lsusb)"
  if [[ $? -eq 0 && -e /sys/bus/usb/devices ]]; then
    echo '> lsusb'
    timeout 10s ${LSUSB} -t
    echo
  fi

  LSBLK="$(which lsblk)"
  if [[ $? -eq 0 && -e /sys/dev/block ]]; then
    echo '> lsblk'
    timeout 10s ${LSBLK}
    echo
  fi

  SMARTCTL="$(which smartctl)"
  if [[ $? -eq 0 ]]; then
    echo '> smartctl'
    if [[ -v FREEBSD ]]; then
      while read -r DEV; do
        DEV="/dev/${DEV//nvd/nvme}"
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

  exit 0
}