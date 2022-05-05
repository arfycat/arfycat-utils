#!/bin/sh

( sync; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; sleep 4; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; sleep 2; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; sleep 1; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; \
  echo s | sudo /usr/bin/tee /proc/sysrq-trigger; \
  echo u | sudo /usr/bin/tee /proc/sysrq-trigger; sleep 8; \
  echo b | sudo /usr/bin/tee /proc/sysrq-trigger; \
)
