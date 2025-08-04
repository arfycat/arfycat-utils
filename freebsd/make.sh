#!/bin/sh
#
# Based on:
#   http://lastsummer.de/creating-custom-packages-on-freebsd/
#   https://docs.freebsd.org/en/books/porters-handbook/plist/
#

DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d.%H%M%S")_$(git rev-parse --short HEAD)"

if [ -d "${STAGEDIR}" ]; then
  rm -rf -- "${STAGEDIR}" || exit $?
fi

if [ ! -d "${STAGEDIR}" ]; then
  mkdir "${STAGEDIR}" || exit $? 
fi

cd "${STAGEDIR}" || exit $?

#
# +MANIFEST
#
cat > "${STAGEDIR}/+MANIFEST" << EOF || exit $?
name: arfycat-utils
version: "${VERSION}"
origin: local
comment: A collection of utilities used by Arfycat hosts.
www: https://github.com/arfycat/arfycat-utils
maintainer: arfycat-utils@arfycat.com
prefix: /usr/local
desc: A collection of utilities used by Arfycat hosts.

deps: {
  bash: {origin: shells/bash}
  flock: {origin: sysutils/flock}
  curl: {origin: ftp/curl}
}
EOF

#
# Create directory structure
#
mkdir -p "${STAGEDIR}/usr/local/bin" || exit $?
mkdir -p "${STAGEDIR}/usr/local/etc" || exit $?
mkdir -p "${STAGEDIR}/usr/local/etc/rc.d" || exit $?
mkdir -p "${STAGEDIR}/usr/local/share/arfycat" || exit $?

#
# Copy files
#
cp "${DIR}/../bash/bashutils.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/cron-status.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/daemon.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/delay.sh" "${STAGEDIR}/usr/local/etc/rc.d/delay" || exit $?
cp "${DIR}/../bash/hc.sh" "${STAGEDIR}/usr/local/bin/hc" || exit $?
cp "${DIR}/../bash/hc.sh" "${STAGEDIR}/usr/local/bin/hcl" || exit $?
cp "${DIR}/../bash/hc.conf" "${STAGEDIR}/usr/local/etc/hc.conf.sample" || exit $?
cp "${DIR}/../bash/hc1.sh" "${STAGEDIR}/usr/local/bin/hc1" || exit $?
cp "${DIR}/../bash/mail-test.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/manage-mining.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/mariabackup.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/monitor-services.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/mysql-backup.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/nsupdate.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/rclone.filter" "${STAGEDIR}/usr/local/etc/rclone.filter.sample" || exit $?
cp "${DIR}/../bash/rclone.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/rclone-b2.filter" "${STAGEDIR}/usr/local/etc/rclone-b2.filter.sample" || exit $?
cp "${DIR}/../bash/rclone-b2.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/rclone-s3c.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/rclone-b2.filter" "${STAGEDIR}/usr/local/share/arfycat/rclone-s3c.filter.sample" || exit $?
cp "${DIR}/../bash/rsync.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/rsync-compare.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/smart-status.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/status.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/status-jail.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/sqlite3-backup-git.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../bash/zfs-snapshot.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit $?
cp "${DIR}/../vim/.vimrc" "${STAGEDIR}/usr/local/share/arfycat/.vimrc.sample" || exit $?

#
# plist
#
cat > "${STAGEDIR}/plist" << EOF || exit $?
@dir(root,wheel,755) share/arfycat
@(root,wheel,755) share/arfycat/bashutils.sh
@(root,wheel,755) share/arfycat/cron-status.sh
@(root,wheel,755) share/arfycat/daemon.sh
@(root,wheel,755) etc/rc.d/delay
@(root,wheel,755) bin/hc
@(root,wheel,755) bin/hc1
@(root,wheel,755) bin/hcl
@sample(root,wheel,644) etc/hc.conf.sample
@(root,wheel,755) share/arfycat/mail-test.sh
@(root,wheel,755) share/arfycat/manage-mining.sh
@(root,wheel,755) share/arfycat/mariabackup.sh
@(root,wheel,755) share/arfycat/monitor-services.sh
@(root,wheel,755) share/arfycat/mysql-backup.sh
@(root,wheel,755) share/arfycat/nsupdate.sh
@sample(root,wheel,644) etc/rclone.filter.sample
@(root,wheel,755) share/arfycat/rclone.sh
@sample(root,wheel,644) etc/rclone-b2.filter.sample
@(root,wheel,755) share/arfycat/rclone-b2.sh
@(root,wheel,755) share/arfycat/rclone-s3c.sh
@sample(root,wheel,644) share/arfycat/rclone-s3c.filter.sample
@(root,wheel,755) share/arfycat/rsync.sh
@(root,wheel,755) share/arfycat/rsync-compare.sh
@(root,wheel,755) share/arfycat/smart-status.sh
@(root,wheel,755) share/arfycat/status.sh
@(root,wheel,755) share/arfycat/status-jail.sh
@(root,wheel,644) share/arfycat/sqlite3-backup-git.sh
@(root,wheel,755) share/arfycat/zfs-snapshot.sh
@sample(root,wheel,644) share/arfycat/.vimrc.sample
EOF

#
# Package
#
pkg create -m "${STAGEDIR}" -r "${STAGEDIR}" -p "${STAGEDIR}/plist" || exit $?
