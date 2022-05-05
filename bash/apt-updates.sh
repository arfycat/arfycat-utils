#!/bin/bash
RET=0

apt-get update -qq > /dev/null || RET=$?

if command -v unattended-upgrade &> /dev/null; then
  unattended-upgrade || RET=$?
fi

apt list --upgradable -qq 2>&1 | grep -v 'does not have a stable CLI interface' | egrep -v '^$'
exit $RET
