#!/usr/bin/env bash
{
  umask 077

  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <Check ID> <Command> [Arguments] ..."
    exit 1
  fi

  if [[ -r ~/.hc.conf ]]; then
    PING_URL="$(cat ~/.hc.conf)"; [[ $? -ne 0 ]] && exit 127
  elif [[ -r /usr/local/etc/hc.conf ]]; then
    PING_URL="$(cat /usr/local/etc/hc.conf)"; [[ $? -ne 0 ]] && exit 127
  elif [[ -r /etc/hc.conf ]]; then
    PING_URL="$(cat /etc/hc.conf)"; [[ $? -ne 0 ]] && exit 127
  else
    PING_URL="https://hc-ping.com"
  fi

  DATE="$(date +%Y%m%d_%H%M%S)"
  CHECK_ID="$1"
  PING_URL="${PING_URL}/${CHECK_ID}"
  shift

  CMD="$1"
  shift

  # lock(): Obtains an exclusive lock to ensure the script is only running once.  A simpler variation of the logic in
  #   bashutils.sh as the full logic is not required here.
  lock() {
    if [ -d "/var/lock" ]; then
      LOCK_FILE="/var/lock/hc-${PING_URL//[^[:alnum:]\.\-]/_}.lock"
    else
      LOCK_FILE="/tmp/hc-${PING_URL//[^[:alnum:]\.\-]/_}.lock"
    fi
    exec 3> "${LOCK_FILE}"

    flock -xn 3 || exit 0
  }

  if [[ "$(basename "$0")" == "hcl" ]]; then
    # If we can get the lock immediately, we proceed with the remaining logic.  Otherwise, lock will exit with 0, nothing
    # further gets executed, and HealthChecks is not pinged at all.
    lock || exit 127
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

  "${CMD}" "$@" > "${TMP_LOG}" 2>&1
  RET=$?

  CURL_ARGS="-fs --connect-timeout 10 -m 60 --retry 10 -o /dev/null -w %{http_code}"
  if [[ -s "${TMP_LOG}" ]]; then
    HC_CODE="$(timeout -k10 65s curl ${CURL_ARGS} --data-binary "@${TMP_LOG}" "${PING_URL}/${RET}")"
    HC_RET=$?
  else
    HC_CODE="$(timeout -k10 65s curl ${CURL_ARGS} "${PING_URL}/${RET}")"
    HC_RET=$?
  fi

  if [[ ${HC_RET} -ne 0 || "${HC_CODE}" != "200" ]]; then
    LOG_DIR="log/hc"
    LOG="$(basename "${CMD}")-${DATE}.log"
    cd && mkdir -p "${LOG_DIR}" && mv -- "${TMP_LOG}" "${LOG_DIR}/${LOG}" > /dev/null 2>&1
  fi

  exit ${RET}
}