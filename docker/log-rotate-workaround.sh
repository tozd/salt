#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# Programs in Docker containers sometimes hang with an error like:
#  svlogd: pausing: unable to rename current: /var/log/mongod: access denied
# This script tries to find such programs and restarts their containers.

for PID in $(ps -o pid,cmd -A | grep 'svlogd: pausing' | awk '{print $1}') ; do
  CONTAINER=$(container-from-pid "$PID" 2>/dev/null || true)

  if [[ -z "$CONTAINER" ]]; then
    continue
  fi

  docker restart "$CONTAINER"
done
