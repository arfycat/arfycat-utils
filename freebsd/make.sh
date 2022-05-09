#!/bin/sh
#
# Based on:
#   http://lastsummer.de/creating-custom-packages-on-freebsd/
#   https://docs.freebsd.org/en/books/porters-handbook/plist/
#

DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d.%H%M%S")"

if [ -d "${STAGEDIR}" ]; then
  rm -rf -- "${STAGEDIR}" || exit 1
fi

if [ ! -d "${STAGEDIR}" ]; then
  mkdir "${STAGEDIR}" || exit 1
fi

cd "${STAGEDIR}" || exit 1

#
# +MANIFEST
#
cat > "${STAGEDIR}/+MANIFEST" << EOF || exit 1
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

mkdir -p "${STAGEDIR}/usr/local/bin" || exit 1
mkdir -p "${STAGEDIR}/usr/local/etc" || exit 1
mkdir -p "${STAGEDIR}/usr/local/share/arfycat" || exit 1
cp "${DIR}/../bash/bashutils.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../bash/cron-status.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../bash/hc" "${STAGEDIR}/usr/local/bin/" || exit 1
cp "${DIR}/../bash/hc.conf" "${STAGEDIR}/usr/local/etc/hc.conf.sample" || exit 1
cp "${DIR}/../bash/rclone.filter" "${STAGEDIR}/usr/local/etc/rclone.filter.sample" || exit 1
cp "${DIR}/../bash/rclone.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../bash/rclone-b2.filter" "${STAGEDIR}/usr/local/etc/rclone-b2.filter.sample" || exit 1
cp "${DIR}/../bash/rclone-b2.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../bash/status.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../vim/.vimrc" "${STAGEDIR}/usr/local/share/arfycat/.vimrc.sample" || exit 1
#
# plist
#
cat > "${STAGEDIR}/plist" << EOF || exit $?
@dir(root,wheel,755) share/arfycat
@(root,wheel,755) share/arfycat/bashutils.sh
@(root,wheel,755) share/arfycat/cron-status.sh
@(root,wheel,755) bin/hc
@sample(root,wheel,644) etc/hc.conf.sample
@sample(root,wheel,644) etc/rclone.filter.sample
@(root,wheel,755) share/arfycat/rclone.sh
@sample(root,wheel,644) etc/rclone-b2.filter.sample
@(root,wheel,755) share/arfycat/rclone-b2.sh
@(root,wheel,755) share/arfycat/status.sh
@sample(root,wheel,644) share/arfycat/.vimrc.sample
EOF

pkg create -m "${STAGEDIR}" -r "${STAGEDIR}" -p "${STAGEDIR}/plist" || exit $?
