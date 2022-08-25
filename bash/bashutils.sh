#!/usr/bin/env bash
# if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo "Failed to source arfycat/bashutils.sh"; exit 255; fi
{
  set -u

  # Script must be sourced.
  if [[ "$BASH_SOURCE" == "$0" ]]; then return 1; fi

  # Ensure the script is only sourced once.
  if [[ -v ARFYCAT_BASHUTILS ]]; then return 0; fi
  ARFYCAT_BASHUTILS="$(realpath "$BASH_SOURCE")"

  CLEANUP_FUNCTIONS=()
  CLEANUP_FILES=()
  CLEANUP_DIRS=()
  WAIT_PIDS=()

  cleanup() {
    for (( i = 0; i < ${#CLEANUP_FILES[@]}; i++ ));
    do
      rm -f -- "${CLEANUP_FILES[$i]}"
    done

    for (( i = 0; i < ${#CLEANUP_DIRS[@]}; i++ ));
    do
      rmdir -- "${CLEANUP_DIRS[$i]}"
    done

    for (( i = 0; i < ${#CLEANUP_FUNCTIONS[@]}; i++ ));
    do
      ${CLEANUP_FUNCTIONS[$i]}
    done
  }
  trap "{ cleanup; }" EXIT
  
  cleanup_add_function() {
    while [[ $# -gt 0 ]];
    do
      CLEANUP_FUNCTIONS+=($1)
      shift
    done
  }

  cleanup_add_file() {
    while [[ $# -gt 0 ]];
    do
      CLEANUP_FILES+=("$1")
      shift
    done
  }

  cleanup_add_dir() {
    while [[ $# -gt 0 ]];
    do
      CLEANUP_DIRS+=("$1")
      shift
    done
  }

  wait_pids_add() {
    while [[ $# -gt 0 ]];
    do
      WAIT_PIDS+=("$1")
      shift
    done
  }

  wait_pids() {
    for (( i = 0; i < ${#WAIT_PIDS[@]}; i++ ));
    do
      wait "${WAIT_PIDS[$i]}"
    done
    WAIT_PIDS=()
  }

  get_tmp_file() {
    local _TMPFILE="$(mktemp)"; [[ $? -ne 0 ]] && fail 1 "get_tmp_file(): Failed to create temporary file."
    cleanup_add_file "${_TMPFILE}"

    if [[ $# -gt 0 ]]; then
      local -n _VAR=$1
      _VAR="${_TMPFILE}"
    else
      echo "${_TMPFILE}"
    fi
  }

  get_tmp_dir() {
    local _TMPDIR="$(mktemp -d)"; [[ $? -ne 0 ]] && fail 1 "get_tmp_dir(): Failed to create temporary directory."
    cleanup_add_dir "${_TMPDIR}"

    if [[ $# -gt 0 ]]; then
      local -n _VAR=$1
      _VAR="${_TMPDIR}"
    else
      echo "${_TMPDIR}"
    fi
  }

  # fail(): Outputs an optional failure message to stderr and exits.
  fail() { # [return code], [message]
    [[ ! $# ]] && exit 255
    RET=${1}
    shift
    [[ $# -ge 1 ]] && echo "$@" >&2
    exit ${RET}
  }

  # get_basename_noext(): Returns the basename of a path without extension.
  get_basename_noext() { # <path>
    [[ $# -eq 0 ]] && fail 1 "user(): Invalid arguments, missing path."
    local FILE="$(realpath "$1")"; [[ $? -ne 0 ]] && fail 1 "get_basename_noext(): Failed to execute: realpath $1"
    local BASENAME="$(basename "$FILE")"; [[ $? -ne 0 ]] && fail 1 "get_basename_noext(): Failed to execute: basename ${FILE}"
    echo "${BASENAME%%.*}"
    return 0
  }

  # user(): Ensures script is executed as the user.
  user() { # <username>
    [[ $# -eq 0 ]] && fail 1 "user(): Invalid arguments, missing username."
    local USER="$1"
    shift
    
    local USER_UID="$(id -u "${USER}")"; local _R=$?
    if [[ $_R -ne 0 ]]; then
      fail $_R "Unknown user: ${USER}"
    fi
    
    if [[ ${USER_UID} -eq ${UID} ]]; then
      # Already running as the requested user.
      return 0
    elif [[ ${UID} -eq 0 ]]; then
      # We are root and can try to become the requested user.
      cleanup
      SHELL="${BASH}" exec su ${USER} -- "$(realpath "$0")" "$@"
      exit 255
    elif [[ $(whoami) != ${USER} || ${UID} -ne ${USER_UID} ]]; then
      fail 1 "$0 must be run as ${USER}"
    fi
    return 0
  }

  # lock(): Obtains an exclusive lock to ensure the script is only running once.
  lock() { # <wait time in seconds>, [lock file suffix]
    local SUFFIX=""
    if [[ $# -ge 2 ]]; then SUFFIX="-$2"; fi

    local SCRIPT="$(realpath "${0}")"

    if [ -d "/var/lock" ]; then
      local LOCK="/var/lock/${SCRIPT//[^[:alnum:]\.\-]/_}${SUFFIX//[^[:alnum:]\.\-]/_}.lock"
    else
      local LOCK="/tmp/${SCRIPT//[^[:alnum:]\.\-]/_}${SUFFIX//[^[:alnum:]\.\-]/_}.lock"
    fi
    exec 3> "${LOCK}"

    if [[ $# -ge 1 && "$1" != "" && $1 -gt 0 ]]; then
      flock -w $1 -xn 3 || exit 0
    else
      flock -xn 3 || exit 0
    fi

    cleanup_add_file "$LOCK"
  }

  log() {
    local SUFFIX=""
    if [[ $# -ge 1 ]]; then SUFFIX="-$1"; fi

    local SCRIPT="$(realpath "${0}")"
    local LOG="$(realpath ~)/log/${SCRIPT//[^[:alnum:]\.\-]/_}${SUFFIX}.log"
    : > "${LOG}" || fail 1 "Failed to write to log file: ${LOG}"
    exec &> >(tee "${LOG}")
  }

  get_home() {
    if [[ $# -ge 1 ]]; then
      local USER="$1"
    else
      local USER="$(whoami)"; [ $? -ne 0 ] && fail 1 "get_home(): Failed to execute whoami to get current user."
    fi

    local PASSWD="$(getent passwd "$USER")"; [[ $? -ne 0 ]] && fail 1 "get_home(): Failed to call getent on user: $USER"
    local HOME="$(echo "$PASSWD" | awk -F':' '{print $6}')"; [[ $? -ne 0 || "${HOME}" == "" || ! -d "${HOME}" ]] && fail 1 "get_home(): Failed to ge
  t home directory for user: ${USER}"

    echo "$HOME"
    return 0
  }

  kill_pid() {
    [[ $# -eq 0 ]] && fail 1 "kill_pid(): Invalid arguments, missing PID."
    local PID="$1"
    if [[ $# -gt 1 ]]; then
      local TIMEOUT="$2"
    else
      local TIMEOUT="5"
    fi
    
    SECONDS=0
    while [[ ${SECONDS} -lt ${TIMEOUT} ]]; do
      kill "${PID}" > /dev/null 2>&1
      ps "${PID}" > /dev/null || return 0
      sleep "0.1"
    done

    ps "${PID}" > /dev/null || return 0
    echo "PID ${PID} failed to exit, sending SIGKILL."
    kill -9 "${PID}" 2>&1 > /dev/null
    ps "${PID}" > /dev/null || return 0
    sleep 1
    ps "${PID}" > /dev/null && { echo "PID ${PID} refuses to die after SIGKILLL."; return 1; }
    return 0
  }

  kill_procs() {
    [[ $# -eq 0 ]] && return 0
    local PIDS="$1"
    if [[ $# -gt 1 ]]; then
      local TIMEOUT="$2"
    else
      local TIMEOUT="5"
    fi

    for PID in ${PIDS}; do
      kill "${PID}" > /dev/null 2>&1
    done

    for PID in ${PIDS}; do
      kill_pid "${PID}" "${TIMEOUT}"
    done

    RET=0
    for PID in ${PIDS}; do
      ps "${PID}" > /dev/null && RET=1
    done
    return ${RET}
  }

  cmd() {
    [[ $# -eq 0 ]] && fail 1 "cmdf(): Invalid arguments, usage: cmd <command> [arg1] ... [argN]"
    if [[ -v DEBUG ]]; then echo "$@"; fi
    "$@"
    return $?
  }

  cmdf() {
    [[ $# -lt 2 ]] && fail 1 "cmdf(): Invalid arguments, usage: cmdf <output file> <command> [arg1] ... [argN]"
    local OUTFILE="$1"; shift
    if [[ -v DEBUG ]]; then echo "$@"; fi
    "$@" 2>&1 > "${OUTFILE}"
    return $?
  }

  cmdv() {
    [[ $# -lt 2 ]] && fail 1 "cmdv(): Invalid arguments, usage: cmdv <output variable> <command> [arg1] ... [argN]"
    local -n OUTVAR="$1"; shift
    if [[ -v DEBUG ]]; then echo "$@"; fi
    OUTVAR="$("$@")"
    return $?
  }

  cleanup-ssh-agent() {
    eval $(ssh-agent -k) > /dev/null
  }

  get-ssh-agent() {
    ssh-add -l >& /dev/null
    if [[ $? -eq 2 ]] ; then
      cleanup_add_function cleanup-ssh-agent
      eval $(ssh-agent -s -t 60) > /dev/null || return $?
    fi

    return 0
  }

  ssh-agent-add() {
    [[ $# -lt 2 ]] && fail 1 "ssh-agent-add(): Invalid arguments, usage: ssh-agent-add <identity file> <passphrase file> [identity lifetime in seconds]"
    get-ssh-agent || return $?

    local SSH_ADD_ARGS=("-q")
    if [[ $# -ge 3 ]]; then
      SSH_ADD_ARGS+=("-t")
      SSH_ADD_ARGS+=("$3")
    fi

    timeout -k 1 5 sshpass -P "passphrase" -f "$2" ssh-add "${SSH_ADD_ARGS[@]}" "$1" || return $?
  }
    
  [[ -v DEBUG ]] && env | sort
  return 0
}