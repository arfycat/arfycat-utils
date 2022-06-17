#!/usr/local/bin/bash

# $FreeBSD$
#
# PROVIDE: delay
# REQUIRE: devd ipfw pf routing
#
# Based on FreeBSD /etc/rc.d/delay
#   https://cgit.freebsd.org/src/tree/libexec/rc/rc.d/delay?id=e29711da2352dae50c575ab884399a6147e9444d
#
# The delay script helps handle two situations:
#  - Systems with USB or other late-attaching network hardware which
#    is initialized by devd events.  The script waits for all the
#    interfaces named in the delay_if list to appear.
#  - Systems with statically-configured IP addresses in rc.conf(5).
#    The IP addresses in the delay_ip list are pinged.  The script
#    waits for any single IP in the list to respond to the ping.  If your
#    system uses DHCP, you should probably use synchronous_dhclient="YES"
#    in your /etc/rc.conf instead of delay_ip.
# Either or both of the wait lists can be used (at least one must be
# non-empty if delay is enabled).

. /etc/rc.subr

name="delay"
desc="Wait for network devices or the network being up"
rcvar="delay_enable"

start_cmd="${name}_start"
stop_cmd=":"

delay_start()
{
  local ip rc count output link wait_if got_if any_error

  if [[ -z "${delay_if}" && -z "${delay_ip}" ]]; then
    err 1 "No interface or IP addresses listed, nothing to wait for"
  fi

  if [[ -n "${delay_if}" && ${delay_if_timeout} -lt 1 ]]; then
    err 1 "delay_if_timeout must be >= 1"
  fi

  if [[ -n "${delay_ip}" && ${delay_ip_timeout} -lt 1 ]]; then
    err 1 "delay_ip_timeout must be >= 1"
  fi

  if [[ -n "${delay_if}" ]]; then
    any_error=0
    for wait_if in ${delay_if}; do
      echo -n "Waiting for ${wait_if}"
      link=""
      got_if=0
      # Handle SIGINT (Ctrl-C); force abort of while() loop
      trap break SIGINT
      SECONDS=0
      while [[ ${SECONDS} -le ${delay_if_timeout} ]]; do
        if output=`/sbin/ifconfig ${wait_if} 2>/dev/null`; then
          if [[ ${got_if} -eq 0 ]]; then
            echo -n ", interface present"
            got_if=1
          fi
          link=`expr "${output}" : '.*[[:blank:]]status: \(no carrier\)'`
          if [[ -z "${link}" ]]; then
            echo ', got link.'
            break
          fi
        fi
        sleep 0.25
      done
      # Restore default SIGINT handler
      trap - SIGINT
      if [[ ${got_if} -eq 0 ]]; then
        echo ", wait failed: interface never appeared."
        any_error=1
      elif [[ -n "${link}" ]]; then
        echo ", wait failed: interface still has no link."
        any_error=1
      fi
    done
    if [[ ${any_error} -eq 1 ]]; then
        warn "Continuing with startup, but be aware you may not have "
        warn "a fully functional networking layer at this point."
    fi
  fi

  if [[ -n "${delay_ip}" ]]; then
    # Handle SIGINT (Ctrl-C); force abort of for() loop
    trap break SIGINT

    for ip in ${delay_ip}; do
      echo -n "Waiting for ${ip} to respond to ICMP ping"

      SECONDS=0
      while [[ ${SECONDS} -le ${delay_ip_timeout} ]]; do
        /usr/bin/timeout -k5 5 /sbin/ping -t 1 -c 1 -o ${ip} >/dev/null 2>&1
        rc=$?

        if [[ $rc -eq 0 ]]; then
          # Restore default SIGINT handler
          trap - SIGINT

          echo ', got response.'
          return
        fi

        sleep 0.25
      done
      echo ', failed: No response from host.'
    done

    # Restore default SIGINT handler
    trap - SIGINT

    warn "Exhausted IP list.  Continuing with startup, but be aware you may"
    warn "not have a fully functional networking layer at this point."
  fi
}

load_rc_config $name
run_rc_command "$1"