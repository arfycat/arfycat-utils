#!/bin/bash -x
#
# Based on: https://betterprogramming.pub/how-to-create-a-basic-debian-package-927be001ad80
#

umask 022

DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d-%H%M%S")"
PKGDIR="${STAGEDIR}/arfycat-utils_${VERSION}_all"
PKGSDIR="${DIR}/packages"

repo() {
  if [[ ! -d "${PKGSDIR}" ]]; then
    mkdir "${PKGSDIR}" || return 1
  fi

  find "${STAGEDIR}" -name "*.deb" -exec cp {} "${PKGSDIR}"/ \;
  cd "${PKGSDIR}" || return 1
  rm -f -- Release
  apt-ftparchive packages . > Packages || return 1
  gzip -9kf Packages || return 1
  TMP="$(mktemp)"
  apt-ftparchive release . > "${TMP}" || { rm -f -- "${TMP}"; return 1; }
  mv "${TMP}" Release || return 1
}

package() {
  if [ -d "${STAGEDIR}" ]; then
    sudo rm -rf -- "${STAGEDIR}" || exit 1
  fi

  if [ ! -d "${STAGEDIR}" ]; then
    mkdir "${STAGEDIR}" || exit 1
  fi

  if [[ ! -d "${PKGSDIR}" ]]; then
    mkdir "${PKGSDIR}" || exit 1
  fi

  cd "${STAGEDIR}" || exit 1
  mkdir "${PKGDIR}" || exit 1

  #
  # DEBIAN/control
  #
  mkdir -p "${PKGDIR}/DEBIAN"
  cat > "${PKGDIR}/DEBIAN/control" << EOF || exit 1
Package: arfycat-utils
Version: ${VERSION}
Architecture: all
Homepage: https://github.com/arfycat/arfycat-utils
Maintainer: arfycat-utils@arfycat.com
Description: A collection of utilities used by Arfycat hosts.
Depends: bash, curl, sshpass, util-linux
EOF

  #
  # DEBIAN/conffiles
  #
  cat > "${PKGDIR}/DEBIAN/conffiles" << EOF || exit 1
/etc/hc.conf
/etc/rclone.filter
/etc/rclone-b2.filter
EOF

  mkdir -p "${PKGDIR}/etc" || exit 1
  mkdir -p "${PKGDIR}/usr/bin" || exit 1
  mkdir -p "${PKGDIR}/usr/share/arfycat" || exit 1
  cp "${DIR}/../bash/apt-updates.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/bashutils.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/cron-status.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/hc" "${PKGDIR}/usr/bin/" || exit 1
  cp "${DIR}/../bash/hc.conf" "${PKGDIR}/etc/" || exit 1
  cp "${DIR}/../bash/rclone.filter" "${PKGDIR}/etc/" || exit 1
  cp "${DIR}/../bash/rclone.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/rclone-b2.filter" "${PKGDIR}/etc/" || exit 1
  cp "${DIR}/../bash/rclone-b2.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/status.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  cp "${DIR}/../bash/sysrq-reboot.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
  sudo chown -R root:root "${PKGDIR}" || exit 1
  sudo chmod -R u+Xrw,g+Xr-w,o+Xr-w "${PKGDIR}" || exit 1
  dpkg-deb -Z xz --build "${PKGDIR}" || exit 1
}

if [[ $# -ge 1 && "$1" == "repo" ]]; then
  repo; exit $?
elif [[ $# -ge 1 && "$1" == "package" ]]; then
  package; exit $?
else
  package || exit $?
  repo; exit $?
fi
