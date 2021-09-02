#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# Programs in Docker containers sometimes hang with an error like:
#  svlogd: pausing: unable to rename current: /var/log/mongod: access denied
# Sometimes this is visible through ps command line (feature of runsvdir) and
# sometimes through Docker logs.
# This script tries to find such programs and restarts their containers.

for PID in $(ps -o pid,cmd -A | grep 'svlogd: pausing' | awk '{print $1}') ; do
  CONTAINER=$(container-from-pid "$PID" 2>/dev/null || true)

  if [[ -z "$CONTAINER" ]]; then
    continue
  fi

  docker restart "$CONTAINER"
done

for CONTAINER in $(docker ps -q) ; do
  if docker logs "$CONTAINER" 2>&1 | grep -q 'svlogd: pausing' ; then
    # We first stop it, so that there is nothing going into logs anymore.
    docker stop "$CONTAINER"

    # Logs are retained between restarts, so we have to clear them first to not get into a loop.
    truncate -s 0 "$(docker inspect --format='{{.LogPath}}' "$CONTAINER")"

    docker restart "$CONTAINER"
  fi
done