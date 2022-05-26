#!/usr/bin/env bash
{
  umask 077

  usage() {
    echo "Usage: $0 [-n <Nice>] [-t <Timeout Seconds>] <Check ID> <Command> [Arguments] ..."
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

    flock -xn 3 || exit 0
  }

  BASENAME="$(basename "$0")"
  if [[ "${BASENAME}" == "hcl" ]]; then
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
  
  CURL_ARGS="-fs --connect-timeout 5 -m 15 -o /dev/null -w %{http_code}"
  if [[ -s "${TMP_LOG}" ]]; then
    CURL_CMD="timeout -k3 15s curl ${CURL_ARGS} --data-binary @${TMP_LOG}"
  else
    CURL_CMD="timeout -k3 15s curl ${CURL_ARGS}"
  fi

  SECONDS=0
  while :; do
    for URL in ${PING_URLS}; do
      echo "HealthChecks: ${CURL_CMD} ${URL}/${CHECK_ID}/${RET}"
      HC_CODE="$(${CURL_CMD} "${URL}/${CHECK_ID}/${RET}")"
      HC_RET=$?
      echo "Return: ${HC_RET}, HTTP status: ${HC_CODE}"

      if [[ ${HC_RET} -eq 0 && "${HC_CODE}" == "200" ]]; then
        exit ${RET}
      fi
      
      sleep 0.1
    done

    if [[ ${SECONDS} -gt ${TIMEOUT} ]]; then
      break
    fi
  done

  # Failed to ping HealthChecks, try to save the log and log to syslog.
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
    else
      [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) Failed to ping HealthChecks, failed to move command output log, discarded."
    fi
  else
    [[ -v LOGGER ]] && ${LOGGER_CMD} "(${USER}) Failed to ping HealthChecks, command output log: ${LOG_DIR}/${LOG}"
  fi

  exit ${RET}
}
