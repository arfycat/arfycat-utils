#!/usr/bin/env bash
if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
PATH="${PATH}:/usr/local/sbin:/usr/sbin:/sbin"

if [[ -f /etc/mailname ]]; then
  HOST="$(cat /etc/mailname)"
else
  HOST="$(hostname -f)"
fi

if [[ $? -gt 0 ]]; then
  TO="$1"
else
  TO="root"
fi

cat <<EOF | sendmail ${TO}
Subject: TEST $(date) 
From: Test Script $0 on ${HOST} <$(whoami)@${HOST}>

This is a test of the email system.  If this was an actual email, there would be some actual content.

$(uuidgen)
EOF
