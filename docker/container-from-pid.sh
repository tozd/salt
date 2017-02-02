#!/bin/bash -e
# Prints the name of the container inside which the process with a PID on the host is.

function getName {
  local pid="$1"

  if [[ -z "$pid" ]]; then
    echo "Missing host PID argument."
    exit 1
  fi

  if [ "$pid" -eq "1" ]; then
    echo "Unable to resolve host PID to a container name."
    exit 2
  fi

  # ps returns values potentially padded with spaces, so we pass them as they are without quoting.
  local parentPid="$(ps -o ppid= -p $pid)"
  local containerId="$(ps -o args= -f -p $parentPid | grep docker-containerd-shim | cut -d ' ' -f 2)"

  if [[ -n "$containerId" ]]; then
    local containerName="$(docker inspect --format '{{.Name}}' "$containerId" | sed 's/^\///')"
    if [[ -n "$containerName" ]]; then
      echo "$containerName"
    else
      echo "$containerId"
    fi
  else
    getName "$parentPid"
  fi
}

getName "$1"