#!/bin/bash -x
#
# Based on: https://betterprogramming.pub/how-to-create-a-basic-debian-package-927be001ad80
#

umask 022

DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d-%H%M%S")"
PKGDIR="${STAGEDIR}/arfycat-utils_${VERSION}_all"

if [ -d "${STAGEDIR}" ]; then
  sudo rm -rf -- "${STAGEDIR}" || exit 1
fi

if [ ! -d "${STAGEDIR}" ]; then
  mkdir "${STAGEDIR}" || exit 1
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
Depends: bash, curl, util-linux
EOF

#
# DEBIAN/conffiles
#
cat > "${PKGDIR}/DEBIAN/conffiles" << EOF || exit 1
/etc/hc.conf
EOF

mkdir -p "${PKGDIR}/etc" || exit 1
mkdir -p "${PKGDIR}/usr/bin" || exit 1
mkdir -p "${PKGDIR}/usr/share/arfycat" || exit 1
cp "${DIR}/../bash/bashutils.sh" "${PKGDIR}/usr/share/arfycat/" || exit 1
cp "${DIR}/../bash/hc" "${PKGDIR}/usr/bin/" || exit 1
cp "${DIR}/../bash/hc.conf" "${PKGDIR}/etc/"
sudo chown -R root:root "${PKGDIR}" || exit 1
sudo chmod -R u+Xrw,g+Xr-w,o+Xr-w "${PKGDIR}" || exit 1

dpkg-deb --build "${PKGDIR}" || exit 4
