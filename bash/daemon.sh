#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 127; fi
  umask 007
  set -o pipefail

  usage() {
    fail 255 "Usage: $0 <User> <Working Directory> <Executable Path> [installed | pause | restart | restore (default) | resume | status | start | stop]"
  }
  
  if [[ $# -lt 3 ]]; then usage; exit 255; fi

  export USER="${1}"
  if ! id -u "${USER}" > /dev/null 2>&1; then exit 127; fi
  user "$USER" "$@"
  
  [[ ! -v UID ]] && fail 255 "Missing shell variable UID."
  export HOST="$(hostname)"; [[ $? -ne 0 ]] && fail 255 "Failed determine hostname."

  export USER_HOME="$(get_home "${USER}")"
  export DIR="$(realpath "${2}")"; _R=$?; [[ ${_R} -ne 0 ]] && fail "${_R}" "Failed to determine realpath: ${2}"
  [[ ! -d "${DIR}" ]] && fail $? "Directory: ${DIR} does not exist."
  cd "${DIR}" || fail $? "Failed to change to directory: ${DIR}."

  export EXEC="$(PATH="${PATH}:${DIR}" which "${3}")"; _R=$?; [[ ${_R} -ne 0 ]] && fail "${_R}" "Failed to locate executable: ${3}"
  [[ ! -x "${EXEC}" ]] && fail $? "Executable: $(EXEC) does not exist or not executable."

  export FILE="$(basename "${EXEC}")"; _R=$?; [[ ${_R} -ne 0 ]] && fail "${_R}" "Failed to determine executable basename: ${EXEC}"
  shift 3

  if [[ $# -ge 1 && "$1" == "installed" ]]; then
    if [[ ! -x "${EXEC}" ]]; then exit 127; else exit 0; fi
  fi

  LOG="${USER_HOME}/log/${FILE}.log"
  mkdir -p "$(dirname "${LOG}")" || fail $? "Failed to create directory for log file."

  STOP="${USER_HOME}/run/stop-${FILE}"
  mkdir -p "$(dirname "${STOP}")" || fail $? "Failed to create directory for stop file."

  PAUSE="${USER_HOME}/run/pause-${FILE}"
  mkdir -p "$(dirname "${PAUSE}")" || fail $? "Failed to create directory for pause file."

  ARGS_FILE="${DIR}/${FILE}-args.txt"
  if [[ -f "${ARGS_FILE}" ]]; then
    ARGS="$(cat "${ARGS_FILE}" | env envsubst)"; _R=$?; [[ ${_R} -ne 0 ]] && fail "${_R}" "Failed to read arguments file: ${ARGS_FILE}"
  else
    ARGS=
  fi
  
  if [[ "$(uname)" == "FreeBSD" ]]; then
    CONT_ARG="-CONT"
    STOP_ARG="-STOP"
  else
    CONT_ARG="-CONT"
    STOP_ARG="-STOP"
  fi

  if [[ $# -ge 1 && "${1}" != "--" ]]; then CMD="$1"; shift; else CMD="restore"; fi
  case $CMD in
    pause) ;;
    restart) ;;
    restore) ;;
    resume) ;;
    start) ;;
    status) ;;
    stop) ;;
    *) usage; exit 255
  esac
  [[ $# -ge 1 && "${1}" == "--" ]] && shift

  lock 360 "${EXEC}"

  # 2: Should be stopped
  # 3: Should be running
  # 4: Should be paused
  # 5: Should not be paused
  status() {
    if [[ -f "${STOP}" ]]; then
      if pgrep -U ${UID} "^${FILE}$" > /dev/null; then
        echo "ERROR: RUNNING"
        exit 2
      else
        echo "OK: STOPPED"
        exit 0
      fi
    elif [[ -f "${PAUSE}" ]]; then
      PID="$(pgrep -U ${UID} "^${FILE}$")"
      if [[ $? -eq 0 ]]; then
        STATE="$(ps -o state= "${PID}")"
        if [[ $? -eq 0 ]]; then
          if [[ "${STATE}" =~ "T" ]]; then
            echo "OK: PAUSED"
            exit 0
          else
            echo "ERROR: RUNNING"
            exit 4
          fi
        else
          echo "OK: STOPPED"
          exit 0
        fi
      else
        echo "OK: STOPPED"
        exit 0
      fi
    else
      PID="$(pgrep -U ${UID} "^${FILE}$")"
      if [[ $? -ne 0 ]]; then
        echo "ERROR: STOPPED"
        exit 3
      else
        STATE="$(ps -o state= "${PID}")"
        if [[ $? -eq 0 ]]; then
          if [[ "${STATE}" =~ "T" ]]; then
            echo "ERROR: PAUSED"
            exit 5
          else
            echo "OK: RUNNING"
            exit 0
          fi
        else
          echo "ERROR: STOPPED"
          exit 3
        fi
      fi
    fi

    # Not supposed to get here.
    exit 255
  }

  case $CMD in
    pause)
      touch "${PAUSE}" || fail $? "Failed to touch pause file: ${PAUSE}"
      ;;
    resume)
      rm -f -- "${PAUSE}" || fail $? "Failed to delete pause file: ${PAUSE}"
      ;;
    start)
      rm -f "${STOP}" || fail $? "Failed to delete stop file: ${STOP}"
      ;;
    status)
      status; exit 255
      ;;
    stop)
      touch "${STOP}" || fail $? "Failed to touch stop file: ${STOP}"
      ;;
    *)
      ;;
  esac

  if [[ -f "${STOP}" ]]; then
    PIDS="$(pgrep -xU ${UID} "^${FILE}$")"
    [[ $? -ne 0 ]] && { status; exit 255; }
    echo "Stopping PID: ${PIDS}"
    kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."

    PIDS="$(pgrep -xU ${UID} "^${FILE}$")"
    [[ $? -ne 0 ]] && { status; exit 255; }
    echo "Stopping PID: ${PIDS}"
    kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    status; exit 255
  fi

  if [[ -f "${PAUSE}" ]]; then
    pgrep -xU ${UID} "^${FILE}$" > /dev/null || { status; exit 255; }
    pkill ${STOP_ARG} -xU ${UID} "^${FILE}$" > /dev/null || fail $? "Failed to pause existing ${FILE} processes."
    status; exit 255
  fi

  if [[ "${CMD}" == "restart" ]]; then
    PIDS="$(pgrep -xU ${UID} "^${FILE}$")"
    if [[ $? -eq 0 ]]; then
      echo "Stopping PID: ${PIDS}"
      kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    fi

    PIDS="$(pgrep -xU ${UID} "^${FILE}$")"
    if [[ $? -eq 0 ]]; then
      echo "Stopping PID: ${PIDS}"
      kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    fi
  fi

  if pgrep -xU ${UID} "^${FILE}$" > /dev/null; then
    pkill ${CONT_ARG} -xU ${UID} "^${FILE}$" > /dev/null || fail $? "Failed to resume existing ${FILE} processes."
    status; exit 255
  fi

  if [[ -v NICE && "${NICE}" != "0" && "${NICE}" != "" ]]; then
    nice "-n${NICE}" "${EXEC}" ${ARGS} "$@" > "${LOG}" 2>&1 &
    RET=$?; PID=$!
  else
    "${EXEC}" ${ARGS} "$@" > "${LOG}" 2>&1 &
    RET=$?; PID=$!
  fi

  if [[ ${RET} -ne 0 ]]; then fail ${RET} "Failed to start process: ${EXEC}" ${ARGS} "$@"; fi
  sleep 3
  ps -p ${PID} > /dev/null || fail $? "Process failed."
  pgrep -xU ${UID} "^${FILE}$" > /dev/null || fail $? "Process failed."
  status; exit 255
}
