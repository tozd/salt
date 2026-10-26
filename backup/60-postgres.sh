{#-
  Collects a PostgreSQL container's contents for the backup, installed as /etc/backup.d/60-<name>-postgres.

  Requires "name" in the context, which names the dump directory /srv/backup/<name>-pgsql. By default it expects the conventions the docker state deploys
  a database with: a container named "<name>-pgsql" whose cluster is owned by the "postgres" role, with its data directory bind-mounted from
  /srv/storage/<name>-pgsql/data to /var/lib/postgresql, like how https://gitlab.com/tozd/docker/postgresql Docker image does it. A container laid out
  differently is described with optional "container", "data_dir" (the bind-mounted directory on the host) and "container_data_dir" (where it is mounted
  inside the container) in the context. The cluster is always expected to be owned by the "postgres" role.

  What it collects follows backup:lvm, so that a machine is consistently in one mode or the other. It is the other half of kopiaignore.conf, which is what
  decides whether the data directory itself is backed up.
-#}
{%- set backup_lvm = salt['pillar.get']('backup:lvm', {}) -%}
{%- set pg_container = container | default(name ~ '-pgsql') -%}
{%- set pg_data_dir = data_dir | default('/srv/storage/' ~ name ~ '-pgsql/data') -%}
{%- set pg_container_data_dir = container_data_dir | default('/var/lib/postgresql') -%}
#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------
{%- if backup_lvm %}

# The backup copies the database files themselves out of a filesystem snapshot.
docker exec {{ pg_container }} psql --username=postgres --command='CHECKPOINT' > /dev/null
{%- else %}

set -o pipefail

CONTAINER={{ pg_container }}
OUT_DIR=/srv/backup/{{ name }}-pgsql
TMP_DIR=$OUT_DIR.tmp

# We reuse the database volume to write the dump into, and because it and /srv/backup sit on the same filesystem, moving
# each finished dump out of it afterwards is a rename rather than a copy.
STAGE={{ pg_container_data_dir }}/backup-staging
STAGE_ON_HOST={{ pg_data_dir }}/backup-staging

trap 'rm --recursive --force "$TMP_DIR" "$STAGE_ON_HOST"' EXIT

rm --recursive --force "$TMP_DIR" "$STAGE_ON_HOST"
mkdir --parents "$TMP_DIR"

# Created from inside the container so that it belongs to the user the database runs as, which is the one writing into it.
docker exec "$CONTAINER" mkdir --parents "$STAGE"

DATABASES=$(docker exec "$CONTAINER" psql --username=postgres --no-align --tuples-only \
  --command="SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname")

if [ -z "$DATABASES" ]; then
  echo "$CONTAINER returned no databases to dump" >&2
  exit 1
fi

docker exec "$CONTAINER" pg_dumpall --username=postgres --globals-only > "$TMP_DIR/globals.sql"

# Left uncompressed on purpose, Kopia will compress it. Level 0 rather than "none", which PostgreSQL 15 does not accept.
while read -r DB; do
  docker exec "$CONTAINER" pg_dump --username=postgres --serializable-deferrable --format=directory --compress=0 \
    --file="$STAGE/$DB" "$DB"

  mv "$STAGE_ON_HOST/$DB" "$TMP_DIR/$DB"
done <<< "$DATABASES"

rm --recursive --force "$OUT_DIR.previous"

if [ -d "$OUT_DIR" ]; then
  mv "$OUT_DIR" "$OUT_DIR.previous"
fi

mv "$TMP_DIR" "$OUT_DIR"
rm --recursive --force "$OUT_DIR.previous"
{%- endif %}
