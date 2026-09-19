# Backup

Hourly [kopia](https://kopia.io/) snapshots of the machine into an encrypted repository, together with the
data which is not in the filesystem to begin with and has to be collected before the snapshot is taken.

The state needs `mailer:root_alias` in the pillar, which is what the cron jobs it installs mail their output
to, so it is used together with the `mailer` state.

## Pillar configuration

All of this goes under `backup:` in the machine's pillar. Without the section the collection scripts still
run, so that what they collect is at least present on the local disk, and kopia is not invoked at all.

```yaml
backup:
  password: |
    -----BEGIN PGP MESSAGE-----
    ...
    -----END PGP MESSAGE-----

  # What gets snapshotted. What gets left out of is configured through .kopiaignore files.
  source: /

  # Optional. The volume holding the data being backed up. With this set kopia reads from a snapshot of that
  # volume instead of from the volume itself, so everything on it is captured as it was at one instant.
  lvm:
    volume_group: vg0
    logical_volume: srv
    snapshot_size: 100G
    mountpoint: /srv

  # How many snapshots to keep. The policy is pushed to the repository when connecting for the first time
  # and by the weekly verification, and snapshots which fall outside it are expired by the next snapshot run,
  # so a change here lands on the following Sunday.
  retention:
    keep_latest: 10
    keep_hourly: 48
    keep_daily: 14
    keep_weekly: 8
    keep_monthly: 24
    keep_annual: 3

  # Share of files the weekly verification downloads and re-hashes. Checking that every snapshot is complete
  # is cheap and always done. Actually reading the data back is what catches corruption at the destination,
  # and it costs a download of this share of the repository every week.
  verify_files_percent: 1

  # How many errors the verification collects before giving up.
  verify_max_errors: 100

  # How full the destination is allowed to get before the weekly verification complains. Checked after
  # maintenance, so what it sees is the space left once the expired snapshots have been reclaimed.
  destination_full_percent: 95
```

Retention buckets are independent and a snapshot can satisfy several at once, so the numbers do not add up:
with one snapshot an hour the settings above keep roughly 90 snapshots, hourly granularity for the last
two days thinning out to three years. Deduplication means an old monthly costs only the chunks unique to
it.

### Destination: SFTP

```yaml
destination:
  type: sftp
  host: uXXXXXX.your-storagebox.de
  port: 22
  username: uXXXXXX-sub1
  path: /kopia
  key: |
    -----BEGIN PGP MESSAGE-----
    ...
    -----END PGP MESSAGE-----
  known_hosts: |
    uXXXXXX.your-storagebox.de ssh-ed25519 AAAA...
    uXXXXXX.your-storagebox.de ssh-rsa AAAA...
```

`key` is the private key in ordinary OpenSSH form without a passphrase.
Collect `known_hosts` with `ssh-keyscan uXXXXXX.your-storagebox.de`.

### Destination: a directory

```yaml
destination:
  type: filesystem
  path: /mnt/backup/kopia
```

That is all the backup needs to know. The repository path is added to `/.kopiaignore` automatically, because
a snapshot of `/` would otherwise read back the repository it is being written into.

## Collecting additional data

Some of what is worth keeping is not a file until something writes it out: the partition tables, the package
selections, the database contents of a server which is not being snapshotted. The scripts in `/etc/backup.d`
run before the snapshot is taken and write what they collect into `/srv/backup`, which is then picked up by
the snapshot like anything else on the filesystem.

The ones shipped here cover what any machine has, and are numbered up to 50:

| Script        | What it writes out                                                         |
| ------------- | -------------------------------------------------------------------------- |
| `10-allfiles` | a listing of every file, so that a restore can be compared against it      |
| `20-packages` | package selections, manual and held packages, debconf answers              |
| `30-disks`    | partition tables, RAID and LVM layout, what was mounted                    |
| `40-system`   | distribution, kernel, enabled units, addresses, routes, firewall, hardware |
| `50-docker`   | the containers, images and volumes which are supposed to exist             |

The directory is managed without `clean`, so other states can add scripts of their own for the data only they
know how to collect. Such a state requires `file: /etc/backup.d` and numbers its script above 50 so that it
runs after the ones above. `60-postgres.sh` here is one of these, ready to be instantiated per database, and
is described under [Databases](#databases).

Scripts are run in filename order by `run-parts`, and a failing one does not prevent the snapshot, because a
backup missing one of the collected files is much better than no backup at all. The failure is reported
through the exit status, so it still produces cron mail.

## Reading from an LVM snapshot

With an `lvm:` section configured, a run goes like this:

1. The scripts in `/etc/backup.d` run and write what they collect into `/srv/backup`.
2. A snapshot of the volume is created. Creating one suspends the origin volume, which freezes the
   filesystem mounted on it and flushes its pending writes, so what the snapshot holds is a consistent
   filesystem image rather than one which has to be repaired before it can be read.
3. Kopia runs with that snapshot mounted read-only over the configured mountpoint, inside a private
   mount namespace, so that the directory structure is preserved.
4. The snapshot volume is removed.

This is what makes it safe to back up the files of a running database directly instead of dumping it first.
Everything on the volume comes from the same instant, so the database files and whatever was written alongside
them, such as content-addressed blobs kept next to the database, cannot disagree about what was committed. A
database restored from these files recovers exactly the way it would after a power loss.

### Read errors

The global policy tolerates read errors, because on a live filesystem a file which changes or disappears
while it is being read is normal, and one such file must not throw away the whole snapshot. That reasoning
does not hold for what is read out of the snapshot: nothing there can change while it is being read, so
an error is a real one, most likely a failing disk. The snapshot-backed mountpoint therefore gets a policy
of its own where errors are fatal.

Kopia still writes the snapshot when it hits one of these, so whatever could be read is kept rather than
discarded, and the run exits non-zero, which is what turns it into cron mail.

### Sizing the snapshot

The snapshot only has to hold the blocks which change on the origin volume while the backup runs. It is not a
copy of the volume, so it costs nothing at rest beyond the free extents reserved for it. If it does fill up
the kernel invalidates it, every read from it fails and the run reports that the backup is incomplete.
Every run logs how much of it was used:

```bash
$ journalctl --identifier=backup | grep copy-on-write
```

Raise `snapshot_size` if that number creeps up. The volume group has to have that much unallocated space,
which `vgs` reports as `VFree`.

## Databases

A database cannot be copied file by file while the server is writing to it, so how it is backed up depends
on whether there is a snapshot to read it out of. Both halves of the answer read `backup:lvm` from the
pillar, so that a machine is consistently in one mode or the other:

|                   | with `lvm:`                             | without                                 |
| ----------------- | --------------------------------------- | --------------------------------------- |
| data directory    | backed up as it is                      | excluded through its own `.kopiaignore` |
| collection script | flushes only, so that recovery is short | dumps the contents into `/srv/backup`   |

Whether the left column is valid at all is for the database to say, and not every one says the same.
PostgreSQL documents filesystem-snapshot backup as supported when the snapshot is atomic and includes the
write-ahead log. A database which documents its own snapshot API as the only supported way (e.g.,
Elasticsearch) gets no such guarantee from an atomic filesystem snapshot, whatever it does in practice,
and the dump stays what is relied on.

### PostgreSQL

Both halves are already written, for a PostgreSQL running in a container, and a state only instantiates them
per database:

```yaml
/srv/storage/example-pgsql/.kopiaignore:
  file.managed:
    - source: salt://backup/kopiaignore.conf
    - template: jinja
    - context:
        elasticsearch: false
    - user: root
    - group: root
    - mode: 644

/etc/backup.d/60-example-postgres:
  file.managed:
    - source: salt://backup/60-postgres.sh
    - template: jinja
    - context:
        name: example
    - user: root
    - group: root
    - mode: 755
    - require:
        - file: /etc/backup.d
```

They expect a container named `example-pgsql` whose cluster is owned by the `postgres` role, with its data
directory bind-mounted from `/srv/storage/example-pgsql/data`, like how the
[tozd/docker/postgresql](https://gitlab.com/tozd/docker/postgresql) Docker image does it.

With `lvm:` configured the script only issues a `CHECKPOINT`, which flushes the dirty buffers and shortens
the recovery of the copy taken a moment later, and the `.kopiaignore` leaves nothing out, so the data
directory goes into the snapshot as it is.

Without `lvm:` the `.kopiaignore` leaves `data` out and the script dumps instead, into
`/srv/backup/example-pgsql`: `pg_dumpall --globals-only` for the roles and tablespaces, then one
`pg_dump --format=directory --serializable-deferrable` per database. `--serializable-deferrable` waits for a
snapshot free of serialization anomalies, so each dump holds a state the database could have reached by
running the concurrent transactions one at a time. Databases are dumped one after another, so they are
individually consistent but not consistent with each other. The dumps are written uncompressed, because
kopia compresses and deduplicates them far better than a compressed dump would allow.

`pg_dump` runs inside the container, which can only write to the database volume, so the dumps are staged
there and moved into `/srv/backup` as they finish. Both sit on the same filesystem, so that is a rename
rather than a copy. The finished set replaces the previous one only once it is complete, so a run which is
interrupted halfway leaves the last complete set behind rather than a partial one.

### Elasticsearch

Only the `.kopiaignore` half is written here, because what the other half should do depends on whether the
index can be rebuilt. Elasticsearch documents its snapshot API as the only supported method and gives no
supported way to restore from a copy of a data directory, so the file-level copy is not something to rely
on: a single node restored from an atomic filesystem snapshot behaves like one restarted after a power loss
and in practice comes up, but that only ever makes a good day faster.

If the index is derived from another database and can be reindexed from it, which is the common case, then
that reindexing is the restore path. Give the directory the template with `elasticsearch: true`, which
leaves out a `snapshots` directory beside the data, and write no collection script. Without `lvm:` nothing of
the index is then kept at all, and with it the data directory rides along in the filesystem snapshot as
something which might save a rebuild but is not what the restore counts on.

If it cannot be reindexed, the snapshot API has to produce the copy. Register a filesystem repository once,
of type `fs`, with `path.repo` pointing at that same `snapshots` directory, so `/srv/storage/example-es/snapshots`
for a container `example-es`, give the storage directory the template with `elasticsearch: false` so that
`snapshots` is backed up rather than left out, and add a script above 50 in `/etc/backup.d` which takes a
snapshot into it before kopia runs, along the lines of:

```bash
docker exec example-es curl --fail --silent --show-error --request PUT \
  "localhost:9200/_snapshot/backup/$SNAPSHOT_NAME?wait_for_completion=true"
```

The data directory itself stays out of the backup without `lvm:`, exactly as before, because the repository
is now what a restore reads. Kopia picks the repository up like any other directory and deduplicates it, so
each run costs only the segments which are not in the backup already. Expiring old snapshots out of the
repository is the script's job too, otherwise it only grows.

## Watching the destination fill

The weekly verification reports how full the destination is and fails above `destination_full_percent`.
Free space comes from `df` for a filesystem destination and from the `df` command of sftp for a remote one,
which relies on a protocol extension the server has to implement. A destination which does not answer is
not treated as an error, it is logged and passed over.

The figure is also logged on every weekly run:

```bash
$ journalctl --identifier=backup | grep "destination is"
```

## Creating the repository

The repository is created once by hand, after the first deploy:

```bash
$ backup create
```

That creates the repository there with the settings from the pillar, connects this machine to it, applies
the policy, and runs `kopia repository validate-provider` to check that the destination really behaves the
way kopia assumes. It refuses to run if the machine is already connected to a repository, and kopia itself
refuses to create one where a repository already exists, so neither an existing repository nor a second
one can be made by accident.

It is a separate step rather than something the scheduled job does when it finds nothing: a destination which
is empty because a share failed to mount or a path was mistyped would otherwise quietly become a second,
empty repository, and every run after that would report success while backing up there.

Once the repository exists, run the job by hand rather than waiting for the next hour, since the first run reads the whole filesystem and is worth watching:

```bash
$ screen
$ backup
```

Only one run happens at a time, and one which finds the lock taken exits quietly rather than mailing, since
colliding with a long snapshot or with the weekly verification is ordinary at hourly cadence.

## Changing the destination later

Changing anything about the destination does not take effect on its own, because the job connects only when
it is not connected already and kopia stores the connection details in `/var/lib/kopia/repository.config`.
Run `kopia repository disconnect` on the machine after such a change, and the next run reconnects with
the new settings.

## Getting data back

The repository is not browsable: it is encrypted, packed blobs with hashed names, and it takes kopia plus the password to read anything out of it.

```bash
$ kopia snapshot list                    # with retention reasons
$ kopia mount all /mnt/restore           # browse every snapshot as a filesystem
$ kopia restore <snapshot-id> <target>   # or straight to a directory, .zip or .tar.gz
```

How a database comes back depends on which mode produced the backup.

From a snapshot-backed run its data directory behaves as though the server had lost power: start it and it
replays its write-ahead log. Restore the whole `/srv/storage/example-pgsql` directory rather than parts of
it, and restore it together with anything sharing its transactions, such as blob storage the application
keeps beside the database.

From a dump-backed run, `/srv/backup/example-pgsql/` holds `globals.sql` and one directory per database.
Load the globals first, then each database:

```bash
$ psql --username=postgres -f globals.sql
$ createdb --username=postgres <db> && pg_restore --username=postgres --dbname=<db> <db>/
```
