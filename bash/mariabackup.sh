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

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c)
        COMPRESS=
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

  local_cleanup() {
    if [[ -d "${TMPDIR}/mariadb" ]]; then
      rm -rf -- "${TMPDIR}/mariadb"
    fi

    cleanup
  }
  trap local_cleanup EXIT

  TMPDIR=; get_tmp_dir TMPDIR
  mkdir "${TMPDIR}/mariadb" || fail $? "Failed to create temporary directory."
  chown :mariabackup "${TMPDIR}/mariadb" || fail $? "Failed to chown temporary directory."
  cd "${TMPDIR}/mariadb" || fail $? "Failed to change directory."

  mariabackup --backup "--target-dir=${TMPDIR}/mariadb" || fail $? "Failed to create backup."

  DATE="$(date "+%Y%m%d-%H%M%S")"; [[ $? -ne 0 ]] && fail 1 "Failed to get date."
  TMPFILE=; get_tmp_file TMPFILE || fail $? "Failed to create temporary file."
  chown :mariabackup "${TMPFILE}" || fail $? "Failed to chown temporary file."

  if [[ -v COMPRESS ]]; then
    BACKUP="${BACKUPDIR}/backup-${DATE}.tar.xz"
    nice -n20 tar cvfj "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create compressed TAR file."
  else
    BACKUP="${BACKUPDIR}/backup-${DATE}.tar"
    nice -n20 tar cvf "${TMPFILE}" -C "${TMPDIR}" mariadb || fail $? "Failed to create TAR file."
  fi

  find "${BACKUPDIR}" -mtime +1 -type f -delete
  mv -- "${TMPFILE}" "${BACKUP}" || fail $? "Failed to move backup file."
  ls -al "${BACKUPDIR}"
  exit $?
}