#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  set -euo pipefail
  umask 077

  user meow "$@"
  lock

  . $HOME/nsupdate.env || fail $? "Failed to source nsupdate.env file."

  IPV4_RE="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
  IPV6_RE="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

  if which dig > /dev/null; then DIG=; fi
  if which drill > /dev/null; then DRILL=; fi

  if [[ ! -v NSUPDATE ]]; then
    NSUPDATE="$(which nsupdate)"
  fi

  _nsupdate() {
    local TYPE="$1"
    local DATA="$2"
    local HOST="$3"
    local ZONE="$4"

    if [[ -v DIG ]]; then
      local QUERY="$(dig +norecurse +short -r -t $TYPE -p $PORT @$SERVER $HOST)" || true
    elif [[ -v DRILL ]]; then
      # The FreeBSD drill doesn't have the short option yet.
      local QUERY="$(drill -o rd -p $PORT $HOST @$SERVER $TYPE | grep -Ev '^;;|^$|SOA' | cut -w -f5)"
    else
      exit 1 "No supported DNS client."
    fi

    if [[ $QUERY == "" || $QUERY != $DATA ]]; then
      echo "$HOST $TYPE $DATA"
      ${NSUPDATE} -k $HOME/nsupdate.key <<EOF
server $SERVER $PORT
zone $ZONE
update delete $HOST $TYPE
update add $HOST 60 $TYPE $DATA
send
EOF
    fi
    return 0
  }

  if [[ -v HOST_E && $HOST_E != "" ]]; then
    EIPV4="$(curl -s4 "${IP_URL_E}")" || true
    EIPV6="$(curl -s6 "${IP_URL_E}")" || true

    if [[ $EIPV4 =~ $IPV4_RE ]]; then
      _nsupdate A $EIPV4 $HOST_E $HOST_E
    fi

    if [[ $EIPV6 =~ $IPV6_RE ]]; then
      _nsupdate AAAA $EIPV6 $HOST_E $HOST_E
    fi
  fi

  if [[ -v HOST_I && $HOST_I != "" ]]; then
    IIPV4="$(curl -s4 "${IP_URL_I}")" || true
    IIPV6="$(curl -s6 "${IP_URL_I}")" || true

    if [[ $IIPV4 =~ $IPV4_RE ]]; then
      _nsupdate A $IIPV4 $HOST_I $HOST_I
    fi

    if [[ $IIPV6 =~ $IPV6_RE ]]; then
      _nsupdate AAAA $IIPV6 $HOST_I $HOST_I
    fi
  fi

  exit 0
}
