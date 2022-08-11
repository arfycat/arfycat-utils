#!/usr/bin/env bash
#
# https://mariadb.com/kb/en/mariabackup-overview/#authentication-and-privileges
#   CREATE USER 'mariabackup'@'localhost' IDENTIFIED BY '<PASSWORD>';
#   GRANT RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR ON *.* TO 'mariabackup'@'localhost';
#   FLUSH PRIVILEGES;
#
# > id mariabackup
#   uid=64004(mariabackup) gid=64004(mariabackup) groups=64004(mariabackup),88(mysql)
#
# Restoring
# https://mariadb.com/kb/en/mariabackup-options/#-stream
# > xzcat /backup/mariabackup/<FILE>.xb.xz | mbstream -x
#
# https://mariadb.com/kb/en/mariabackup-options/#-prepare
# > mariabackup --prepare
#
# https://mariadb.com/kb/en/mariabackup-options/#-copy-back
# > mariabackup --copy-back --force-non-empty-directories
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 127; fi
  set -uo pipefail
  umask 077

  user mariabackup "$@"
  lock
  
  if [[ "$(uname)" == "FreeBSD" ]]; then
    MTIME="+2h"
  else
    MTIME="+0.08333"
  fi

  COMPRESS_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        STREAM=
        shift
        ;;
      -c)
        COMPRESS="xz"
        COMPRESS_EXT="xz"
        COMPRESS_ARGS=()
        COMPRESS_ARGS+=("-9")
        COMPRESS_ARGS+=("-T0")
        shift
        ;;
      --bz2)
        COMPRESS="bzip2"
        COMPRESS_EXT="bz2"
        COMPRESS_ARGS=()
        shift
        ;;
      --bz2a)
        COMPRESS="bzip2"
        COMPRESS_EXT="bz2"
        COMPRESS_ARGS+=("$2")
        shift
        shift
        ;;
      --mtime)
        MTIME="$2"
        shift
        shift
        ;;
      --xz)
        COMPRESS="xz"
        COMPRESS_EXT="xz"
        COMPRESS_ARGS=()
        shift
        ;;
      --xza)
        COMPRESS="xz"
        COMPRESS_EXT="xz"
        COMPRESS_ARGS+=("$2")
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

  if [[ $# -lt 1 ]]; then
    BACKUPDIR="/backup/mariabackup"
  else
    BACKUPDIR="$(realpath "$1")"
  fi
  [[ ! -d "${BACKUPDIR}" ]] && fail 1 "Backup directory does not exist: ${BACKUPDIR}"

  if [[ -v STREAM ]]; then
    cd /tmp || fail $? "Failed to change directory: /tmp"

    DATE="$(date "+%Y%m%d-%H%M%S")"; [[ $? -ne 0 ]] && fail 1 "Failed to get date."
    if [[ -v COMPRESS ]]; then
      BACKUP="${BACKUPDIR}/backup-${DATE}.xb.${COMPRESS_EXT}"
      { mariabackup --backup --stream=xbstream | "${COMPRESS}" "${COMPRESS_ARGS[@]}" > "${BACKUP}"; } \
        |& { grep -vE -e "InnoDB: Read redo log up to LSN" -e ">> log scanned up to \([0-9]+\)" -e "DDL tracking : modify [0-9]+ .*" -e "Streaming .* to <STDOUT>" -e "Streaming .*\.ibd" -e "\.\.\.done" || true; } \
        || fail $? "Failed to create compressed XB file."
    else
      BACKUP="${BACKUPDIR}/backup-${DATE}.xb"
      { mariabackup --backup --stream=xbstream > "${BACKUP}"; } \
        |& { grep -vE -e "InnoDB: Read redo log up to LSN" -e ">> log scanned up to \([0-9]+\)" -e "DDL tracking : modify [0-9]+ .*" -e "Streaming .* to <STDOUT>" -e "Streaming .*\.ibd" -e "\.\.\.done" || true; } \
        || fail $? "Failed to create XB file."
    fi
  else
    local_cleanup() {
      if [[ -v TMPDIR && -d "${TMPDIR}/mariadb" ]]; then
        rm -rf -- "${TMPDIR}/mariadb"
      fi

      cleanup
    }

    TMPDIR=; get_tmp_dir TMPDIR
    trap local_cleanup EXIT

    mkdir "${TMPDIR}/mariadb" || fail $? "Failed to create temporary directory."
    chown :mariabackup "${TMPDIR}/mariadb" || fail $? "Failed to chown temporary directory."
    cd "${TMPDIR}/mariadb" || fail $? "Failed to change directory."

    mariabackup --backup "--target-dir=${TMPDIR}/mariadb" || fail $? "Failed to create backup."

    DATE="$(date "+%Y%m%d-%H%M%S")"; [[ $? -ne 0 ]] && fail 1 "Failed to get date."
    TMPFILE=; get_tmp_file TMPFILE || fail $? "Failed to create temporary file."
    chown :mariabackup "${TMPFILE}" || fail $? "Failed to chown temporary file."

    if [[ -v COMPRESS && "${COMPRESS}" == "xz" ]]; then
      BACKUP="${BACKUPDIR}/backup-${DATE}.tar.${COMPRESS_EXT}"
      tar cvfJ "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create xz compressed TAR file."
    elif [[ -v COMPRESS && "${COMPRESS}" == "bzip2" ]]; then
      BACKUP="${BACKUPDIR}/backup-${DATE}.tar.${COMPRESS_EXT}"
      tar cvfy "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create bzip2 compressed TAR file."
    else
      BACKUP="${BACKUPDIR}/backup-${DATE}.tar"
      tar cvf "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create TAR file."
    fi
    mv -- "${TMPFILE}" "${BACKUP}" || fail $? "Failed to move backup file."
  fi

  if [[ "${MTIME}" != "" && "${MTIME}" != "0" ]]; then
    find "${BACKUPDIR}" -mtime "${MTIME}" -type f -delete
  fi

  ls -al "${BACKUPDIR}"
  exit $?
}