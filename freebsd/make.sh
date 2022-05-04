#!/bin/sh
DIR="$(dirname "$(realpath "$0")")"
STAGEDIR="${DIR}/work"
VERSION="$(date "+%Y%m%d-%H%M%S")"

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
mkdir -p "${STAGEDIR}/usr/local/share/arfycat" || exit 1
cp "${DIR}/../bash/bashutils.sh" "${STAGEDIR}/usr/local/share/arfycat/" || exit 1
cp "${DIR}/../bash/hc" "${STAGEDIR}/usr/local/bin/" || exit 1

#
# plist
#
cat > "${STAGEDIR}/plist" << EOF || exit 1
@dir(root,wheel,755) share/arfycat
@(root,wheel,755) bin/hc
@(root,wheel,755) share/arfycat/bashutils.sh
EOF

pkg create -m "${STAGEDIR}" -r "${STAGEDIR}" -p "${STAGEDIR}/plist" || exit 4
