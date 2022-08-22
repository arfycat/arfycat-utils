#!/usr/bin/env bash
{
  umask 077

  usage() {
    echo "Usage: $0 [-n <Nice>] [-t <Timeout Seconds>] [-w <Lock Wait Time in Seconds] <Check ID> <Command> [Arguments] ..."
    exit 1
  }

  if [[ $# -lt 2 ]]; then
    usage
  fi

  if [[ -r ~/.hc.conf ]]; then
    PING_URLS="$(cat ~/.hc.conf)"; [[ $? -ne 0 ]] && exit 127
  elif [[ -r /usr/local/etc/hc.conf ]]; then
    PING_URLS="$(cat /usr/local/etc/hc.conf)"; [[ $? -ne 0 ]] && exit 127
  elif [[ -r /etc/hc.conf ]]; then
    PING_URLS="$(cat /etc/hc.conf)"; [[ $? -ne 0 ]] && exit 127
  else
    PING_URLS="https://hc-ping.com"
  fi

  if [[ -r "${HOME}/.hc.p12" ]]; then
    CLIENT_CERT="${HOME}/.hc.p12"
  elif [[ -r "/usr/local/etc/hc.p12" ]]; then
    CLIENT_CERT="/usr/local/etc/hc.p12"
  elif [[ -r "/etc/hc.p12" ]]; then
    CLIENT_CERT="/etc/hc.p12"
  fi

  WAIT=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d)
        DEBUG=
        shift
        ;;
      -n)
        [[ $# -lt 2 ]] && usage
        NICE="$2"
        shift
        shift
        ;;
      -w)
        [[ $# -lt 2 ]] && usage
        WAIT="$2"
        shift
        shift
        ;;
      -t)
        [[ $# -lt 2 ]] && usage
        TIMEOUT="$2"
        shift
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

  # Discard stdout and stderr if DEBUG is not set.
  [[ ! -v DEBUG ]] && { exec 1>/dev/null; exec 2>/dev/null; }

  # Set a default TIMEOUT if not set.
  [[ ! -v TIMEOUT ]] && TIMEOUT=50

  DATE="$(date +%Y%m%d_%H%M%S)"
  CHECK_ID="$1"
  shift

  CMD="$1"
  shift

  # lock(): Obtains an exclusive lock to ensure the script is only running once.  A simpler variation of the logic in
  #   bashutils.sh as the full logic is not required here.
  lock() {
    if [ -d "/var/lock" ]; then
      LOCK_FILE="/var/lock/hc-${CHECK_ID//[^[:alnum:]\.\-]/_}.lock"
    else
      LOCK_FILE="/tmp/hc-${CHECK_ID//[^[:alnum:]\.\-]/_}.lock"
    fi
    exec 3> "${LOCK_FILE}"

    if [[ $WAIT -gt 0 ]]; then
      flock -x -w $WAIT 3
      return $?
    else
      flock -xn 3
      return $?
    fi
  }

  BASENAME="$(basename "$0")"
  if [[ "${BASENAME}" == "hcl" || $WAIT -gt 0 ]]; then
    # If we can get the lock immediately, we proceed with the remaining logic.  Otherwise, lock will exit with 0, nothing
    # further gets executed, and HealthChecks is not pinged at all.
    lock || { echo "Failed to get lock, exiting without executing command or pinging HealthChecks."; exit 126; }
  fi

  cleanup() {
    if [[ -v TMP_LOG ]]; then
      rm -f -- "${TMP_LOG}"
    fi
    if [[ -v LOCK_FILE ]]; then
      rm -f -- "${LOCK_FILE}"
    fi
  }

  TMP_LOG="$(mktemp)"
  trap cleanup EXIT

  if [[ -v NICE ]]; then
    echo "Command: nice -n ${NICE} ${CMD} $@"
    nice -n "${NICE}" "${CMD}" "$@" > "${TMP_LOG}" 2>&1
    RET=$?
  else
    echo "Command: ${CMD} $@"
    "${CMD}" "$@" > "${TMP_LOG}" 2>&1
    RET=$?
  fi
  echo "Return: ${RET}"
  
  savelog() {
    if [[ ! -f "${TMP_LOG}" ]]; then return 1; fi

    USER="$(whoami)"
    LOGGER="$(which logger)"
    [[ $? -ne 0 ]] && unset LOGGER
    LOGGER_CMD="${LOGGER} -t ${BASENAME}[$$]"
    
    [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) ${CMD} $*: ${RET}"
    LOG_DIR="log/hc"
    LOG="$(basename "${CMD}")-${DATE}.log"
    cd && mkdir -p "${LOG_DIR}" && mv -- "${TMP_LOG}" "${LOG_DIR}/${LOG}"
    if [[ $? -ne 0 ]]; then
      mv -- "${TMP_LOG}" "/tmp/${LOG}"
      if [[ $? -eq 0 ]]; then
        [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) Failed to ping HealthChecks, command output log: /tmp/${LOG}"
        echo "/tmp/${LOG}"
        return 0
      else
        [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) Failed to ping HealthChecks, failed to move command output log, discarded."
        rm -- "${TMP_LOG}"
        return 1
      fi
    fi

    [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) Failed to ping HealthChecks, command output log: ${LOG_DIR}/${LOG}"
    echo "${LOG_DIR}/${LOG}"
    return 0
  }

  CURL_ARGS="-fs --connect-timeout 10 -m 20 -o /dev/null -w %{http_code}"
  if [[ -s "${TMP_LOG}" ]]; then
    CURL_ARGS+=" --data-binary @${TMP_LOG}"
  fi

  SECONDS=0
  HC_CODE=
  while :; do
    for URL in ${PING_URLS}; do
      CURL_URL_ARGS=
      if [[ "$URL" =~ ^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))? ]]; then
        DOMAIN="${BASH_REMATCH[4]}"
        if [[ -r "${HOME}/.config/hc/.${DOMAIN}.p12" ]]; then
          CURL_URL_ARGS+=" --cert-type P12 --cert ${HOME}/.config/hc/${DOMAIN}.p12"
        elif [[ -r "/usr/local/etc/hc/${DOMAIN}.p12" ]]; then
          CURL_URL_ARGS+=" --cert-type P12 --cert /usr/local/etc/hc/${DOMAIN}.p12"
        elif [[ -r "/etc/hc/${DOMAIN}.p12" ]]; then
          CURL_URL_ARGS+=" --cert-type P12 --cert /etc/hc/${DOMAIN}.p12"
        elif [[ -v CLIENT_CERT ]]; then
          CURL_URL_ARGS+=" --cert-type P12 --cert ${CLIENT_CERT}"
        fi
      fi

      CURL_CMD="curl ${CURL_ARGS} ${CURL_URL_ARGS}"
    
      echo "HealthChecks: ${CURL_CMD} ${URL}/${CHECK_ID}/${RET}"
      HC_CODE="$(${CURL_CMD} "${URL}/${CHECK_ID}/${RET}")"
      HC_RET=$?
      echo "Return: ${HC_RET}, HTTP status: ${HC_CODE}"

      if [[ ${HC_RET} -eq 0 && "${HC_CODE}" == "200" ]]; then
        exit ${RET}
      elif [[ "${HC_CODE}" == "413" ]]; then
        if [[ -f "${TMP_LOG}" ]]; then
          SAVED_LOG="$(savelog)"; _R=$?
          if [[ $_R -ne 0 ]]; then
            RET=$_R
            CURL_CMD="timeout -k3 15s curl ${CURL_ARGS}"
          else
            CURL_CMD="timeout -k3 15s curl ${CURL_ARGS} --data-raw ${SAVED_LOG}"
          fi
          break
        fi
      fi

      sleep 0.1
    done

    if [[ ${SECONDS} -gt ${TIMEOUT} ]]; then
      break
    fi
  done

  savelog || RET=$?
  exit ${RET}
}