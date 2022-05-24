#!/usr/bin/env bash
#
# https://mariadb.com/kb/en/mariabackup-overview/#authentication-and-privileges
#   CREATE USER 'mariabackup'@'localhost' IDENTIFIED BY '<PASSWORD>';
#   GRANT RELOAD, PRcOCESS, LOCK TABLES, BINLOG MONITOR ON *.* TO 'mariabackup'@'localhost';
#
# > id mariabackup
#   uid=64004(mariabackup) gid=64004(mariabackup) groups=64004(mariabackup),88(mysql)
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 127; fi
  umask 077

  user mariabackup "$@"
  lock

  local_cleanup() {
    if [[ -d "${TMPDIR}/mariadb" ]]; then
      rm -rf -- "${TMPDIR}/mariadb"
    fi

    cleanup
  }
  trap local_cleanup EXIT

  if [[ $# -lt 1 ]]; then
    BACKUPDIR="/backup/mariabackup"
  else
    BACKUPDIR="$(realpath "$1")"
  fi
  [[ ! -d "${BACKUPDIR}" ]] && fail 1 "Backup directory does not exist: ${BACKUPDIR}"

  TMPDIR=; get_tmp_dir TMPDIR
  mkdir "${TMPDIR}/mariadb" || fail 1 "Failed to create temporary directory."
  chown :mariabackup "${TMPDIR}/mariadb" || fail 1 "Failed to chown temporary directory."

  mariabackup --backup "--target-dir=${TMPDIR}/mariadb" || fail 1 "Failed to create backup."

  DATE="$(date "+%Y%m%d-%H%M%S")"; [[ $? -ne 0 ]] && fail 1 "Failed to get date."
  BACKUP="${BACKUPDIR}/backup-${DATE}.tar.xz"
  TMPFILE=; get_tmp_file TMPFILE || fail $? "Failed to create temporary file."
  chown :mariabackup "${TMPFILE}" || fail $? "Failed to chown temporary file."

  tar cvfj "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create TAR file."
  mv -- "${TMPFILE}" "${BACKUP}" || fail $? "Failed to move backup file."

  find "${BACKUPDIR}" -mtime +1 -type f -delete
  ls -al "${BACKUPDIR}"
  exit $?
}