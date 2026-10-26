{#-
  Collects a MongoDB container's contents for the backup, installed as /etc/backup.d/60-<name>-mongodb.

  Requires "name" in the context, which names the dump directory /srv/backup/<name>-mongodb, and accepts optional "container", the name of the container,
  which defaults to "<name>-mongodb". It expects the conventions of https://gitlab.com/tozd/docker/meteor-mongodb Docker image: a replica set member whose
  "admin" user can list and read all databases, with the password of that user in MONGODB_ADMIN_PWD of /etc/service/mongod/run.config inside the
  container, and no authentication at all when that is empty.

  What it collects follows backup:lvm, so that a machine is consistently in one mode or the other. It is the other half of kopiaignore.conf, which is what
  decides whether the data directory itself is backed up.
-#}
{%- set backup_lvm = salt['pillar.get']('backup:lvm', {}) -%}
{%- set mongodb_container = container | default(name ~ '-mongodb') -%}
#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------

CONTAINER={{ mongodb_container }}

# Commands run inside the container, where run.config holds the password of the admin user. run.config is written for bash and not for a POSIX shell. MongoDB
# tools receive the password on their standard input, never on their command line, which every process on the host can read. They report their progress even
# when everything goes well, so their output is shown only when they fail.
{%- if backup_lvm %}

# The backup copies the database files themselves out of a filesystem snapshot, from which MongoDB recovers through its journal.
#
# The shell is "mongo", or "mongosh" in versions which do not ship "mongo" anymore. Their options for the password differ, but both run a script given on
# standard input and both have db.auth. The script is a single line because "mongo" evaluates its input line by line.
if ! OUTPUT=$(docker exec "$CONTAINER" bash -c '
  . /etc/service/mongod/run.config
  if [ -x "$(command -v mongo)" ]; then
    MONGO=mongo
  else
    MONGO=mongosh
  fi
  AUTH=
  if [ -n "$MONGODB_ADMIN_PWD" ]; then
    printf -v AUTH "db.getSiblingDB(\"admin\").auth(\"admin\", \"%s\"); " "$MONGODB_ADMIN_PWD"
  fi
  FSYNC="var r = db.adminCommand({fsync: 1}); if (!r.ok) { printjson(r); quit(1); }"
  printf "%s\n" "try { ${AUTH}${FSYNC} } catch (e) { print(e); quit(1); }" | "$MONGO" --quiet admin
' 2>&1); then
  echo "$OUTPUT" >&2
  exit 1
fi
{%- else %}

OUT_DIR=/srv/backup/{{ name }}-mongodb
TMP_DIR=$OUT_DIR.tmp

# The dump is written inside the container, which needs no volume of its own for that, and is copied out of it once it is complete.
STAGE=/tmp/backup-staging

trap 'rm --recursive --force "$TMP_DIR"; docker exec "$CONTAINER" rm --recursive --force "$STAGE"' EXIT

rm --recursive --force "$TMP_DIR"
docker exec "$CONTAINER" rm --recursive --force "$STAGE"

# With --oplog the dump also records the writes made while it runs, so that restoring it with --oplogReplay brings all databases to the same instant.
#
# mongodump reads the password from standard input when it asks for one. The Go rewrite of the tools (MongoDB 3.0 onwards) asks when --password is left out,
# while the older C++ one asks only when --password is given without a value.
if ! OUTPUT=$(docker exec "$CONTAINER" bash -c '
  . /etc/service/mongod/run.config
  if [ -z "$MONGODB_ADMIN_PWD" ]; then
    exec mongodump "$@"
  elif mongodump --version 2>&1 | grep --quiet "^Go version"; then
    printf "%s\n" "$MONGODB_ADMIN_PWD" | mongodump --username admin --authenticationDatabase admin "$@"
  else
    printf "%s\n" "$MONGODB_ADMIN_PWD" | mongodump --username admin --password --authenticationDatabase admin "$@"
  fi
' bash --oplog --out "$STAGE" 2>&1); then
  echo "$OUTPUT" >&2
  exit 1
fi

docker cp "$CONTAINER:$STAGE" "$TMP_DIR"

rm --recursive --force "$OUT_DIR.previous"

if [ -d "$OUT_DIR" ]; then
  mv "$OUT_DIR" "$OUT_DIR.previous"
fi

mv "$TMP_DIR" "$OUT_DIR"
rm --recursive --force "$OUT_DIR.previous"
{%- endif %}
