{#-
  Collects a MySQL (MariaDB) container's contents for the backup, installed as /etc/backup.d/60-<name>-mysql.

  Requires "name" in the context, which names the dump directory /srv/backup/<name>-mysql, and accepts optional "container", the name of the container,
  which defaults to "<name>-mysql". It expects the conventions of https://gitlab.com/tozd/docker/mysql Docker image: /etc/mysql/debian.cnf inside the
  container with the credentials of an administrative user, as the Debian packaging of MariaDB maintains it.

  What it collects follows backup:lvm, so that a machine is consistently in one mode or the other. It is the other half of kopiaignore.conf, which is what
  decides whether the data directory itself is backed up.
-#}
{%- set backup_lvm = salt['pillar.get']('backup:lvm', {}) -%}
{%- set mysql_container = container | default(name ~ '-mysql') -%}
#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------

CONTAINER={{ mysql_container }}

# Clients inside the container read the credentials from the file the Debian packaging of MariaDB maintains, so that no password appears on any command line.
# The option has to be the first one given to a client.
DEFAULTS=--defaults-file=/etc/mysql/debian.cnf
{%- if backup_lvm %}

# The backup copies the database files themselves out of a filesystem snapshot. Flushing writes out and closes all tables, which shortens the recovery
# InnoDB performs on the copy and leaves MyISAM tables consistent unless they are written to again before the snapshot is created.
docker exec "$CONTAINER" mysql "$DEFAULTS" --execute='FLUSH TABLES'
{%- else %}

set -o pipefail

OUT_DIR=/srv/backup/{{ name }}-mysql
TMP_DIR=$OUT_DIR.tmp

trap 'rm --recursive --force "$TMP_DIR"' EXIT

rm --recursive --force "$TMP_DIR"
mkdir --parents "$TMP_DIR"

# Every database together with the number of its tables which are not InnoDB.
DATABASES=$(docker exec "$CONTAINER" mysql "$DEFAULTS" --batch --skip-column-names --raw --execute="
  SELECT s.schema_name, (
    SELECT COUNT(*) FROM information_schema.tables t
    WHERE t.table_schema = s.schema_name AND t.table_type = 'BASE TABLE' AND t.engine <> 'InnoDB'
  )
  FROM information_schema.schemata s
  WHERE s.schema_name NOT IN ('information_schema', 'performance_schema', 'sys')
  ORDER BY s.schema_name")

if [ -z "$DATABASES" ]; then
  echo "$CONTAINER returned no databases to dump" >&2
  exit 1
fi

while IFS=$'\t' read -r DB NON_INNODB; do
  # A database whose tables are all InnoDB is dumped from a single transaction, which sees one consistent state without blocking anybody. Other engines do
  # not support transactions, so a database with any table of them has its tables locked for reading while it is dumped, which keeps the dump consistent
  # but makes writes to the database wait until it is done.
  if [ "$NON_INNODB" = 0 ]; then
    CONSISTENCY=--single-transaction
  else
    CONSISTENCY=--lock-tables
  fi

  # Left uncompressed on purpose, Kopia will compress it. Without the dump date an unchanged database produces an identical dump, which Kopia stores only once.
  # mysqldump reports only problems, so its output is shown when it fails.
  if ! OUTPUT=$(docker exec "$CONTAINER" mysqldump "$DEFAULTS" "$CONSISTENCY" --routines --events --triggers --hex-blob --skip-dump-date \
    --default-character-set=utf8mb4 --databases "$DB" 2>&1 > "$TMP_DIR/$DB.sql"); then
    echo "$OUTPUT" >&2
    exit 1
  fi
done <<< "$DATABASES"

rm --recursive --force "$OUT_DIR.previous"

if [ -d "$OUT_DIR" ]; then
  mv "$OUT_DIR" "$OUT_DIR.previous"
fi

mv "$TMP_DIR" "$OUT_DIR"
rm --recursive --force "$OUT_DIR.previous"
{%- endif %}
