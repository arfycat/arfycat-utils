#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  umask 077

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v)
        VERBOSE=
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac 
  done

  if [[ $# -eq 0 ]]; then
    fail 1 "Usage: $0 [-v] [--] <Service Name Regex 1> ... [Service Name Regex N]"
  fi
  
  check_service() {
    local SERVICE="$1"

    if [[ -v VERBOSE ]]; then
      echo "${SERVICE}:"
      local OUT="/dev/stdout"
    else
      local OUT="/dev/null"
    fi

    SECONDS=0
    local RET=1
    while [[ ${SECONDS} -le 60 ]]; do
      service "${SERVICE}" status >& ${OUT}
      RET=$?
      if [[ ${RET} -eq 0 ]]; then
        return 0
      fi
      
      sleep 1
    done
    return $RET
  }

  restart_service() {
    local SERVICE="$1"
    
    if [[ -v VERBOSE ]]; then
      echo "${SERVICE}:"
      local OUT="/dev/stdout"
    else
      local OUT="/dev/null"
    fi
    
    if ! check_service "${SERVICE}"; then
      echo "Restarting ${SERVICE}"
      service "${SERVICE}" restart || return $?
      echo
    fi
    return 0
  }

  RET=0
  while read -r SERVICE; do
    SERVICE="$(basename "${SERVICE}")"
    for REGEX in "$@"; do
      if [[ ${SERVICE} =~ ${REGEX} ]]; then
        restart_service "${SERVICE}" || RET=$?
        break
      fi
    done
  done < <(service -e | sort)
  exit ${RET}
}