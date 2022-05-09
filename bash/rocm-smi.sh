#!/usr/bin/env bash

ROCM_SMI="$(find /opt -wholename "/opt/rocm-*/bin/rocm-smi" -print -quit)"
if [[ $? -eq 0 && "${ROCM_SMI}" != "" ]]; then
  "${ROCM_SMI}" "$@"
  exit $?
else
  echo "Failed to locate rocm-smi." >&2
  exit 1
fi
