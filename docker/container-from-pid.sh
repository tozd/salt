#!/bin/bash -e
# Prints the name of the container inside which the process with a PID on the host is.

docker inspect --format '{{.Name}}' "$(cat /proc/$1/cgroup | head -n 1 | cut -d / -f 3)" | sed 's/^\///'
