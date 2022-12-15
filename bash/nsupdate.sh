#!/usr/bin/env bash
{
  if ! PATH="${PATH}:/usr/local/share/arfycat:/usr/share/arfycat" source bashutils.sh; then echo Failed to source arfycat/bashutils.sh; exit 255; fi
  set -euo pipefail
  umask 077

  lock

  while [[ $# -gt 0 ]]; do
    case $1 in
      -4)
        IPV4=
        shift
        ;;
      -6)
        IPV6=
        shift
        ;;
      debug)
        DEBUG=
        shift
        ;;
      force)
        FORCE=
        shift
      ;;
      *)
        break
        ;;
    esac
  done

  if [[ ! -v IPV4 && ! -v IPV6 ]]; then
    IPV4=
    IPV6=
  fi

  . $HOME/nsupdate.env || fail $? "Failed to source nsupdate.env file."

  IPV4_RE="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
  IPV6_RE="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

  if which dig > /dev/null; then DIG=; fi
  if which drill > /dev/null; then DRILL=; fi

  if [[ ! -v NSUPDATE ]]; then
    NSUPDATE="$(which nsupdate)"
  fi

  CURL_ARGS=()
  if [[ $OSTYPE == "FreeBSD" || $OSTYPE == "freebsd"* ]]; then
    :
  else
    CURL_ARGS+=("--dns-servers")
    CURL_ARGS+=("$RSERVER:$RPORT")
  fi

  _query() {
    local TYPE="$1"
    local HOST="$2"
    local -n VAR=$3

    if [[ -v DIG ]]; then
      VAR="$(dig +short -r -t $TYPE -p $RPORT @$RSERVER $HOST)" || true
    elif [[ -v DRILL ]]; then
      # The FreeBSD drill doesn't have the short option yet.
      VAR="$(drill -p $RPORT $HOST @$RSERVER $TYPE | grep -Ev '^;;|^$|SOA' | cut -w -f5)" || true
    else
      exit 1 "No supported DNS client."
    fi

    if [[ -v DEBUG ]]; then
      echo "_query $TYPE $HOST -> $VAR"
    fi
    return 0
  }

  _query_nr() {
    local TYPE="$1"
    local HOST="$2"
    local -n VAR=$3

    if [[ -v DIG ]]; then
      VAR="$(dig +norecurse +short -r -t $TYPE -p $PORT @$SERVER $HOST)" || true
    elif [[ -v DRILL ]]; then
      # The FreeBSD drill doesn't have the short option yet.
      VAR="$(drill -o rd -p $PORT $HOST @$SERVER $TYPE | grep -Ev '^;;|^$|SOA' | cut -w -f5)" || true
    else
      exit 1 "No supported DNS client."
    fi

    if [[ -v DEBUG ]]; then
      echo "_query_nr $TYPE $HOST -> $VAR"
    fi
    return 0
  }

  _host_from_url() {
    local URL="$1"
    local -n VAR=$2

    if [[ $URL =~ ^.+://([^/?]+) ]]; then
      VAR="${BASH_REMATCH[1]}"
      if [[ -v DEBUG ]]; then
        echo "_host_from_url $URL -> $VAR"
      fi
      return 0
    else
      echo "Failed to obtain host from URL: ${URL}"
      return 1
    fi
  }
 
  _nsupdate() {
    local TYPE="$1"
    local DATA="$2"
    local HOST="$3"
    local ZONE="$4"

    local QUERY=; _query_nr "$TYPE" "$HOST" QUERY
 
    if [[ -v FORCE || $QUERY == "" || $QUERY != $DATA ]]; then
      echo "Updating $HOST $TYPE $DATA"
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
    IP_URL_E_HOST=; _host_from_url $IP_URL_E IP_URL_E_HOST

    if [[ -v IPV4 ]]; then
      IP_URL_E_IP4=; _query A "$IP_URL_E_HOST" IP_URL_E_IP4
      if [[ $IP_URL_E_IP4 =~ $IPV4_RE ]]; then
        EIPV4="$(curl "${CURL_ARGS[@]}" -s4 --resolve "$IP_URL_E_HOST:443:$IP_URL_E_IP4" "$IP_URL_E")" || true
        if [[ $EIPV4 =~ $IPV4_RE ]]; then
          _nsupdate A $EIPV4 $HOST_E $HOST_E
        fi
      fi
    fi

    if [[ -v IPV6 ]]; then
      IP_URL_E_IP6=; _query AAAA "$IP_URL_E_HOST" IP_URL_E_IP6
      if [[ $IP_URL_E_IP6 =~ $IPV6_RE ]]; then
        EIPV6="$(curl "${CURL_ARGS[@]}" -s6 --resolve "$IP_URL_E_HOST:443:$IP_URL_E_IP6" "$IP_URL_E")" || true
        if [[ $EIPV6 =~ $IPV6_RE ]]; then
          _nsupdate AAAA $EIPV6 $HOST_E $HOST_E
        fi
      fi
    fi
  fi

  if [[ -v HOST_I && $HOST_I != "" ]]; then
    IP_URL_I_HOST=; _host_from_url $IP_URL_I IP_URL_I_HOST

    if [[ -v IPV4 ]]; then
      IP_URL_I_IP4=; _query A "$IP_URL_I_HOST" IP_URL_I_IP4
      if [[ $IP_URL_I_IP4 =~ $IPV4_RE ]]; then
        IIPV4="$(curl "${CURL_ARGS[@]}" -s4 --resolve "$IP_URL_I_HOST:443:$IP_URL_I_IP4" "$IP_URL_I")" || true
        if [[ $IIPV4 =~ $IPV4_RE ]]; then
          _nsupdate A $IIPV4 $HOST_I $HOST_I
        fi
      fi
    fi

    if [[ -v IPV6 ]]; then
      IP_URL_I_IP6=; _query AAAA "$IP_URL_I_HOST" IP_URL_I_IP6
      if [[ $IP_URL_I_IP6 =~ $IPV6_RE ]]; then
        IIPV6="$(curl "${CURL_ARGS[@]}" -s6 --resolve "$IP_URL_I_HOST:443:$IP_URL_I_IP6" "$IP_URL_I")" || true
        if [[ $IIPV6 =~ $IPV6_RE ]]; then
          _nsupdate AAAA $IIPV6 $HOST_I $HOST_I
        fi
      fi
    fi
  fi

  exit 0
}
