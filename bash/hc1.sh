#!/usr/bin/env bash
{
  umask 077

  usage() {
    echo "Usage: $0 [-cc <Client Cert>] [-ct <Command Timeout in Seconds>] [-n <Nice>] [-p <Pause Between Attempts in Seconds>] [-r <Retries>] [-t <HealthChecks Timeout in Seconds>] [-w <Lock Wait Time in Seconds] <Check URL> <Command> [Arguments] ..."
    exit 1
  }

  if [[ $# -lt 2 ]]; then
    usage
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -cc)
        CLIENT_CERT="$2"
        shift
        shift
        ;;
      -ct)
        [[ $# -lt 2 ]] && usage
        CMD_TIMEOUT="$2"
        shift
        shift
        ;;
      -d)
        DEBUG=
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

  DATE="$(date +%Y%m%d_%H%M%S)"
  CHECK_URL="$1"
  shift

  CMD="$1"
  shift

  # lock(): Obtains an exclusive lock to ensure the script is only running once.  A simpler variation of the logic in
  #   bashutils.sh as the full logic is not required here.
  lock() {
    LOCK_FILE="/tmp/hc1-${CHECK_URL//[^[:alnum:]\.\-]/_}.lock"
    exec 3> "${LOCK_FILE}" || return $?

    flock -xn 3
    return $?
  }

  unlock() {
    exec 3<&- # flock close
  }

  # If we can get the lock immediately, we proceed with the remaining logic.  Otherwise, lock will exit with 0, nothing
  # further gets executed, and HealthChecks is not pinged at all.
  lock || exit 0

  cleanup() {
    if [[ -v TMP_LOG && -f "${TMP_LOG}" ]]; then
      rm -f -- "${TMP_LOG}"
    fi

    if [[ -v LOCK_FILE && -f "${LOCK_FILE}" ]]; then
      rm -f -- "${LOCK_FILE}"
    fi
  }

  TMP_LOG="$(mktemp)"
  trap cleanup EXIT

  RET=1
  echo "Command: ${CMD} $@"
  "${CMD}" "$@" >& "${TMP_LOG}"
  RET=$?
  echo "Return: ${RET}"
  unlock

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

  CURL_ARGS="-fs --connect-timeout 15 -m 20 -o /dev/null -w %{http_code}"
  CURL_ARGS_NO_DATA="$CURL_ARGS"

  if [[ -s "${TMP_LOG}" ]]; then
    CURL_ARGS+=" --data-binary @${TMP_LOG}"
  fi

  TIMEOUT=3600
  SECONDS=0
  HC_CODE=
  CURL_URL_ARGS=
  if [[ -v CLIENT_CERT ]]; then
    CURL_URL_ARGS+=" --cert-type P12 --cert ${CLIENT_CERT}"
  fi
  CURL_CMD="curl ${CURL_ARGS} ${CURL_URL_ARGS}"

  while :; do
    echo "HealthChecks: ${CURL_CMD} ${CHECK_URL}/${RET}"
    HC_CODE="$(${CURL_CMD} "${CHECK_URL}/${RET}")"
    HC_RET=$?
    echo "Return: ${HC_RET}, HTTP status: ${HC_CODE}"

    if [[ ${HC_RET} -eq 0 && "${HC_CODE}" == "200" ]]; then
      exit ${RET}
    elif [[ "${HC_CODE}" == "413" ]]; then
      if [[ -s "${TMP_LOG}" ]]; then
        SAVED_LOG="$(savelog)"; _R=$?
        if [[ $_R -ne 0 ]]; then
          RET=$_R
          CURL_CMD="curl ${CURL_ARGS_NO_DATA} ${CURL_URL_ARGS}"
        else
          CURL_CMD="curl ${CURL_ARGS_NO_DATA} ${CURL_URL_ARGS} --data-raw ${SAVED_LOG}"
        fi
      fi
    fi

    sleep 60

    if [[ ${SECONDS} -gt ${TIMEOUT} ]]; then
      break
    fi
  done

  savelog || RET=$?
  exit ${RET}
}
