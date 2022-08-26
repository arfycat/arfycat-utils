#!/bin/bash
exec /usr/share/arfycat/daemon.sh --any-user root /tmp /usr/sbin/rsyslogd "$@" -- -n