#!/usr/bin/env bash
{
  set -eu
  RET=0

  RCLONE_CMD=()
  RCLONE_CMD+=("rclone")
  RCLONE_CMD+=("sync")
  RCLONE_CMD+=("-v") # Print lots more stuff (repeat for more)
  RCLONE_CMD+=("--stats") # Interval between printing stats, e.g. 500ms, 60s, 5m (0 to disable) (default 1m0s)
  RCLONE_CMD+=("0")
  RCLONE_CMD+=("-M") # If set, preserve metadata when copying objects
  RCLONE_CMD+=("-l") # Translate symlinks to/from regular files with a '.rclonelink' extension
  RCLONE_CMD+=("--fast-list") # Use recursive list if available; uses more memory but fewer transactions
  RCLONE_CMD+=("--delete-excluded") # Delete files on dest excluded from sync
  RCLONE_CMD+=("--filter-from") # Read file filtering patterns from a file (use - to read from stdin)
  RCLONE_CMD+=("$HOME/.config/arfycat/rclone-s3c.filter")
  RCLONE_CMD+=("/")
  RCLONE_CMD+=("s3c:/")

  echo "${RCLONE_CMD[@]}" "$@"
  "${RCLONE_CMD[@]}" "$@" || RET=$?

  RCLONE_CMD=()
  RCLONE_CMD+=("rclone")
  RCLONE_CMD+=("cryptcheck")
  RCLONE_CMD+=("-v") # Print lots more stuff (repeat for more)
  RCLONE_CMD+=("--stats") # Interval between printing stats, e.g. 500ms, 60s, 5m (0 to disable) (default 1m0s)
  RCLONE_CMD+=("0")
  RCLONE_CMD+=("-l") # Translate symlinks to/from regular files with a '.rclonelink' extension
  RCLONE_CMD+=("--fast-list") # Use recursive list if available; uses more memory but fewer transactions
  RCLONE_CMD+=("--filter-from") # Read file filtering patterns from a file (use - to read from stdin)
  RCLONE_CMD+=("$HOME/.config/arfycat/rclone-s3c.filter")
  RCLONE_CMD+=("/")
  RCLONE_CMD+=("s3c:/")

  echo
  echo "${RCLONE_CMD[@]}"
  "${RCLONE_CMD[@]}" || RET=$?

  exit $RET
}
