#!/bin/bash -x
#
# Based on: https://betterprogramming.pub/how-to-create-a-basic-debian-package-927be001ad80
#

umask 022

DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d.%H%M%S")-$(git rev-parse --short HEAD)"
PKGDIR="${STAGEDIR}/arfycat-utils_${VERSION}_all"
PKGSDIR="${DIR}/packages"

clean() {
  sudo rm -rf -- "${STAGEDIR}"
}

repo() {
  if [[ ! -d "${PKGSDIR}" ]]; then
    mkdir "${PKGSDIR}" || return $?
  fi

  find "${STAGEDIR}" -name "*.deb" -exec cp {} "${PKGSDIR}"/ \;
  cd "${PKGSDIR}" || return $?
  rm -f -- Release
  apt-ftparchive packages . > Packages || return $?
  gzip -9kf Packages || return $?
  TMP="$(mktemp)"
  apt-ftparchive release . > "${TMP}" || { rm -f -- "${TMP}"; return 1; }
  mv "${TMP}" Release || return $?
}

package() {
  if [ -d "${STAGEDIR}" ]; then
    sudo rm -rf -- "${STAGEDIR}" || exit $?
  fi

  if [ ! -d "${STAGEDIR}" ]; then
    mkdir "${STAGEDIR}" || exit $?
  fi

  if [[ ! -d "${PKGSDIR}" ]]; then
    mkdir "${PKGSDIR}" || exit $?
  fi

  cd "${STAGEDIR}" || exit $?
  mkdir "${PKGDIR}" || exit $?

  #
  # DEBIAN/control
  #
  mkdir -p "${PKGDIR}/DEBIAN"
  cat > "${PKGDIR}/DEBIAN/control" << EOF || exit $?
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
  cat > "${PKGDIR}/DEBIAN/conffiles" << EOF || exit $?
/etc/hc.conf
/etc/rclone.filter
/etc/rclone-b2.filter
/etc/vim/vimrc.local
EOF

  mkdir -p "${PKGDIR}/etc/vim" || exit $?
  mkdir -p "${PKGDIR}/usr/bin" || exit $?
  mkdir -p "${PKGDIR}/usr/share/arfycat" || exit $?

  cp "${DIR}/../bash/apt-updates.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/bashutils.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/cron.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/cron-status.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/daemon.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/hc.sh" "${PKGDIR}/usr/bin/hc" || exit $?
  cp "${DIR}/../bash/hc.conf" "${PKGDIR}/etc/" || exit $?
  cp "${DIR}/../bash/mail-test.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/manage-mining.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/manage-power.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/mariabackup.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/nsupdate.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rclone.filter" "${PKGDIR}/etc/" || exit $?
  cp "${DIR}/../bash/rclone.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rclone-b2.filter" "${PKGDIR}/etc/" || exit $?
  cp "${DIR}/../bash/rclone-b2.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rocm-smi.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rsync.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rsync-compare.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/rsyslogd.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/smart-status.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/status.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/sysrq-reboot.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/wsl-init.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../bash/zfs-snapshot.sh" "${PKGDIR}/usr/share/arfycat/" || exit $?
  cp "${DIR}/../vim/.vimrc" "${PKGDIR}/etc/vim/vimrc.local" || exit $?

  ln -s "hc" "${PKGDIR}/usr/bin/hcl" || exit $?

  sudo chown -R root:root "${PKGDIR}" || exit $?
  sudo chmod -R u+Xrw,g+Xr-w,o+Xr-w "${PKGDIR}" || exit $?
  dpkg-deb -Z xz --build "${PKGDIR}" || exit $?
}

if [[ $# -ge 1 && "$1" == "repo" ]]; then
  repo; exit $?
elif [[ $# -ge 1 && "$1" == "package" ]]; then
  package; exit $?
elif  [[ $# -ge 1 && "$1" == "clean" ]]; then
  clean; exit $?
else
  package || exit $?
  repo || exit $?
  clean || exit $?
fi
