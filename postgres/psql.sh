#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------

# Stands in for psql so that Salt's postgres modules reach a PostgreSQL running in a container, without a port published on the host and without a client
# installed beside it. Every one of those modules builds its command through one helper, which runs whatever "psql" resolves to, so replacing that one binary
# is enough to redirect the whole family.
#
# The container is named through the connection host, so a state says "db_host: example-pgsql" and the arguments naming a network destination are turned into a
# choice of container here. That is a lie to anyone reading the state, which is why it is written down: there is no other per-state value to carry it in, the
# host is the only one which reaches this far down.
#
# Setting the host also decides which user this runs as. Salt falls back to running psql as the postgres user when no host is given, and that user is not in the
# docker group. With a host it stays as the user the minion runs as, which is root. The option naming the container is the same one which keeps docker reachable.
#
# Only psql is stood in for, which is used by all Salt's postgres modules except for postgres_initdb (which uses initdb).

set -o pipefail

CONTAINER=
ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      CONTAINER=$2
      shift 2
      ;;
    --host=*)
      CONTAINER=${1#--host=}
      shift
      ;;
    # A port means nothing once the connection is made over the socket inside the container.
    --port)
      shift 2
      ;;
    --port=*)
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -z "$CONTAINER" ]; then
  echo "${0##*/}: no host was given, so there is no container to run in" >&2
  echo "${0##*/}: the postgres states reach a container through db_host, which names it" >&2

  exit 1
fi

# Interactive so that statements arriving on standard input are passed through. There is no terminal involved.
exec docker exec --interactive "$CONTAINER" psql "${ARGS[@]}"
