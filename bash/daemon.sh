#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 127; fi
  umask 007
  set -uo pipefail

  usage() {
    fail 255 "Usage: $0 <User> <Working Directory> <Executable Path> [installed | pause | restart | restore (default) | resume | status | start | stop]"
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --any-user)
        ANY_USER=
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
  
  if [[ $# -lt 3 ]]; then usage; exit 255; fi

  export USER="${1}"
  if ! id -u "${USER}" > /dev/null 2>&1; then exit 127; fi
  user "$USER" "$@"
  
  [[ ! -v UID ]] && fail 255 "Missing shell variable UID."
  export HOST="$(hostname)"; [[ $? -ne 0 ]] && fail 255 "Failed determine hostname."
  
  if [[ -v ANY_USER ]]; then
    PS_ARGS=()
  else
    PS_ARGS=("-U" "${UID}")
  fi

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

  UNAME="$(uname)"; _R=$?; [[ ${_R} -ne 0 ]] && fail "${_R}" "Failed to call uname."
  CONT_ARG="-CONT"
  STOP_ARG="-STOP"

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
  
  daemon_stop() {
    PIDS="$(pgrep -d' ' -x "${PS_ARGS[@]}" "^${FILE}$")"
    [[ $? -ne 0 ]] && { status; exit 255; }
    echo "Stopping PID: ${PIDS}"
    kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."

    PIDS="$(pgrep -d' ' -x "${PS_ARGS[@]}" "^${FILE}$")"
    [[ $? -ne 0 ]] && { status; exit 255; }
    echo "Stopping PID: ${PIDS}"
    kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    status; exit 255
  }
  
  if [[ "${UNAME}" == "Linux" ]]; then
    RUNLEVEL="$(runlevel | cut -d' ' -f2)"
    if [[ $? -eq 0 ]]; then
      # If we were able to determine the runlevel.  WSL does not have a runlevel.
      if [[ "${RUNLEVEL}" == "0" || "${RUNLEVEL}" == "6" ]]; then
        # Either shutdown or reboot.
        echo "Stopping ${EXEC} due to runlevel: ${RUNLEVEL}."
        daemon_stop; exit 255
      fi
    fi
  fi

  lock 360 "${EXEC}"

  # 2: Should be stopped
  # 3: Should be running
  # 4: Should be paused
  # 5: Should not be paused
  status() {
    if [[ -f "${STOP}" ]]; then
      if pgrep "${PS_ARGS[@]}" "^${FILE}$" > /dev/null; then
        echo "ERROR: RUNNING"
        exit 2
      else
        echo "OK: STOPPED"
        exit 0
      fi
    elif [[ -f "${PAUSE}" ]]; then
      local PIDS="$(pgrep "${PS_ARGS[@]}" "^${FILE}$")"
      if [[ $? -eq 0 ]]; then
        local STATE=
        local STATE_TEXT="STOPPED"
        for PID in $PIDS; do
          STATE="$(ps -o state= ${PID})"
          if [[ $? -eq 0 ]]; then
            if [[ "${STATE}" =~ "T" ]]; then
              STATE_TEXT="PAUSED"
            else
              echo "ERROR: RUNNING"
              exit 4
            fi
          fi
        done

        echo "OK: ${STATE_TEXT}"
        exit 0
      else
        echo "OK: STOPPED"
        exit 0
      fi
    else
      PIDS="$(pgrep "${PS_ARGS[@]}" "^${FILE}$")"
      if [[ $? -ne 0 ]]; then
        echo "ERROR: STOPPED"
        exit 3
      else
        for PID in $PIDS; do
          local STATE="$(ps -o state= "${PID}")"
          if [[ $? -eq 0 ]]; then
            if [[ "${STATE}" =~ "T" ]]; then
              echo "ERROR: PAUSED"
              exit 5
            fi
          else
            echo "ERROR: STOPPED"
            exit 3
          fi
        done

        echo "OK: RUNNING"
        exit 0
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
    daemon_stop; exit 255
  fi

  if [[ -f "${PAUSE}" ]]; then
    pgrep -x "${PS_ARGS[@]}" "^${FILE}$" > /dev/null || { status; exit 255; }
    pkill ${STOP_ARG} -x "${PS_ARGS[@]}" "^${FILE}$" > /dev/null || fail $? "Failed to pause existing ${FILE} processes."
    status; exit 255
  fi

  if [[ "${CMD}" == "restart" ]]; then
    PIDS="$(pgrep -d' ' -x "${PS_ARGS[@]}" "^${FILE}$")"
    if [[ $? -eq 0 ]]; then
      echo "Stopping PID: ${PIDS}"
      kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    fi

    PIDS="$(pgrep -d' ' -x "${PS_ARGS[@]}" "^${FILE}$")"
    if [[ $? -eq 0 ]]; then
      echo "Stopping PID: ${PIDS}"
      kill_procs "${PIDS}" 30 || fail $? "Failed to kill existing ${FILE} processes."
    fi
  fi

  if pgrep -x "${PS_ARGS[@]}" "^${FILE}$" > /dev/null; then
    pkill ${CONT_ARG} -x "${PS_ARGS[@]}" "^${FILE}$" > /dev/null || fail $? "Failed to resume existing ${FILE} processes."
    status; exit 255
  fi

  if [[ -v NICE && "${NICE}" != "0" && "${NICE}" != "" ]]; then
    nice "-n${NICE}" "${EXEC}" ${ARGS} "$@" >& "${LOG}" &
    RET=$?; PID=$!
  else
    "${EXEC}" ${ARGS} "$@" >& "${LOG}" &
    RET=$?; PID=$!
  fi

  if [[ ${RET} -ne 0 ]]; then fail ${RET} "Failed to start process: ${EXEC}" ${ARGS} "$@"; fi
  sleep 3
  ps -p ${PID} > /dev/null || fail $? "Process failed."
  pgrep -d' ' -x "${PS_ARGS[@]}" "^${FILE}$" || fail $? "Process failed."
  status; exit 255
}
