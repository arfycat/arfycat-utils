#!/usr/bin/env bash
{
  set -euo pipefail

  if [[ -f /etc/mailname ]]; then
    HOST="$(cat /etc/mailname)"
  else
    HOST="$(hostname -f)"
  fi

  if [[ $# -gt 0 ]]; then
    TO="$1"
    shift
  else
    TO="root"
  fi

  if [[ $# -gt 0 ]]; then
    FROM="$1"
    shift
  else
    FROM="$(whoami)@${HOST}"
  fi

  cat <<EOF | sendmail ${TO}
Subject: TEST $(date) 
From: TEST ${HOST} <${FROM}>


Test script: $(realpath "$0") $*
This is a test of the email system.  If this was an actual email, there would be some actual content.

$(uuidgen)
EOF
  exit $?
}

