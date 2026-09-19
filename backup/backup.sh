#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------

# Runs the scripts in /etc/backup.d, which collect additional data to back up into /srv/backup, and then snapshots the configured source into the kopia
# repository described by /etc/backup.conf. Called as "backup verify" it instead verifies the snapshots already in the repository and runs full repository
# maintenance, which is what the weekly job does.
#
# When the pillar configures an LVM volume, kopia reads from a snapshot of it rather than from the live volume. Everything on that volume is then captured as it
# was at one instant, which is what makes it safe to back up the files of a running database directly instead of dumping it first. A database restored from such
# a snapshot recovers the same way it would after a power loss.
#
# Salt writes /etc/backup.conf only when the "backup" pillar section exists. Without it the scripts in /etc/backup.d still run, so that the data they collect is
# at least present on the local disk, and kopia is not invoked at all.

set -o pipefail

# Cron gives a job almost no PATH, and kopia lives in /usr/local/bin, so the full root PATH is set here rather than in the crontab, which also means the script
# behaves the same when it is run by hand.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONFIG_FILE=/etc/backup.conf
SCRIPTS_DIR=/etc/backup.d
DATA_DIR=/srv/backup
LOCK_FILE=/run/lock/backup
STAMP_FILE=/var/lib/kopia/last-snapshot
SFTP_KEY_FILE=/etc/kopia/sftp_key
SFTP_KNOWN_HOSTS_FILE=/etc/kopia/sftp_known_hosts
SNAPSHOT_LV_SUFFIX=-backup-snapshot

now_ms() {
  local T=${EPOCHREALTIME//[.,]/}

  echo $((T / 1000))
}

fmt_ms() {
  printf '%d.%02ds' $(($1 / 1000)) $((($1 % 1000) / 10))
}

START_MS=$(now_ms)

# Kopia is invoked from cron, so it keeps its state in system-wide locations instead of root's home directory.
export KOPIA_CONFIG_PATH=/var/lib/kopia/repository.config
export KOPIA_CACHE_DIRECTORY=/var/cache/kopia
export KOPIA_LOG_DIR=/var/log/kopia

# Disable the update check.
export KOPIA_CHECK_FOR_UPDATES=false

# The lock this script holds stays open on file descriptor 9 for the whole run, and every LVM command inherits it and says so on its standard error. The lock is
# deliberate, so the warning is silenced. Without this each run would produce cron mail saying nothing more than that the lock exists.
export LVM_SUPPRESS_FD_WARNINGS=1

MODE="${1:-backup}"

case "$MODE" in
  backup|verify|create) ;;
  *)
    echo "usage: ${0##*/} [backup|verify|create]" >&2
    exit 2
    ;;
esac

STALE_AFTER_HOURS=6

SNAPSHOTS_STALE=0
if [ -e "$STAMP_FILE" ] && [ -n "$(find "$STAMP_FILE" -mmin "+$((STALE_AFTER_HOURS * 60))")" ]; then
  SNAPSHOTS_STALE=1
fi

# The jobs share the repository, the kopia cache and the snapshot volume, whose name is fixed, so only one run is allowed at a time.
exec 9>"$LOCK_FILE"
if ! flock --nonblock 9; then
  if [ "$SNAPSHOTS_STALE" = 1 ]; then
    echo "lock is held but no snapshot has succeeded since $(date --reference="$STAMP_FILE" '+%Y-%m-%d %H:%M:%S'), a run looks stuck" >&2
    exit 1
  fi

  exit 0
fi

KOPIA_ENABLED=0
if [ -e "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
  export KOPIA_PASSWORD
  KOPIA_ENABLED=1
fi

# Without a volume group configured the backup reads the live filesystem, which is how a machine whose data does not sit on LVM is backed up.
LVM_ENABLED=0
if [ -n "${BACKUP_LVM_VOLUME_GROUP:-}" ]; then
  LVM_ENABLED=1
  ORIGIN_DEVICE="/dev/$BACKUP_LVM_VOLUME_GROUP/$BACKUP_LVM_LOGICAL_VOLUME"
  SNAPSHOT_LV="$BACKUP_LVM_LOGICAL_VOLUME$SNAPSHOT_LV_SUFFIX"
  SNAPSHOT_DEVICE="/dev/$BACKUP_LVM_VOLUME_GROUP/$SNAPSHOT_LV"
fi

QUIET_FLAGS=()
# Is stdout not a terminal? This silences Kopia's noisy output for cron mail.
if [ ! -t 1 ]; then
  QUIET_FLAGS=(--log-level=warning)
fi

JUST_CONNECTED=0
SCRIPTS_FAILED=0
SNAPSHOT_CREATED=0
DESTINATION_ARGS=()

# The snapshot volume is removed however the run ends, because it keeps filling up with the writes the origin volume receives for as long as it exists.
cleanup() {
  local STATUS=$?

  if [ "$SNAPSHOT_CREATED" = 1 ]; then
    remove_snapshot || true
  fi

  logger --tag backup "$MODE finished in $(fmt_ms $(($(now_ms) - START_MS))) with status $STATUS"
}

trap cleanup EXIT

# Builds the "kopia repository" subcommand and the flags addressing the configured destination. The same arguments work for both connect and create, so the
# error path below can print a usable create command.
set_destination_args() {
  case "$BACKUP_DESTINATION_TYPE" in
    filesystem)
      DESTINATION_ARGS=(filesystem "--path=$BACKUP_DESTINATION_PATH")
      ;;
    sftp)
      # The host key is pinned through an explicit known_hosts file rather than the one in root's home directory, so that the file Salt manages is the only
      # thing which decides what this machine is willing to connect to.
      DESTINATION_ARGS=(
        sftp
        "--host=$BACKUP_SFTP_HOST"
        "--port=$BACKUP_SFTP_PORT"
        "--username=$BACKUP_SFTP_USERNAME"
        "--path=$BACKUP_SFTP_PATH"
        "--keyfile=$SFTP_KEY_FILE"
        "--known-hosts=$SFTP_KNOWN_HOSTS_FILE"
      )
      ;;
    *)
      echo "unknown backup destination type: $BACKUP_DESTINATION_TYPE" >&2
      exit 1
      ;;
  esac
}

# Mounts the filesystem the destination sits on (as described in /etc/fstab) if it is not already mounted, and leaves it mounted afterwards.
ensure_destination_mounted() {
  if [ "$BACKUP_DESTINATION_TYPE" != filesystem ]; then
    return 0
  fi

  local DIR=$BACKUP_DESTINATION_PATH
  local TARGETS=()

  # Every mount point /etc/fstab describes between the destination and the root, collected deepest first.
  while [ "$DIR" != / ] && [ "$DIR" != . ]; do
    if findmnt --fstab --noheadings --mountpoint "$DIR" > /dev/null 2>&1; then
      TARGETS+=("$DIR")
    fi

    DIR=$(dirname "$DIR")
  done

  # Mounted the other way round, outermost first. Mounting an inner one while the mount point above it is still missing puts it on a directory which the outer
  # filesystem then covers, and the inner one becomes unreachable while still being listed as mounted, so nothing would notice it had happened.
  local I

  for (( I = ${#TARGETS[@]} - 1; I >= 0; I-- )); do
    # Whether it is mounted is read from the mount table rather than by stat-ing the directory, because stat on a mount whose session has died fails, and
    # mounting over a mount which is already there only produces "device or resource busy".
    if ! findmnt --noheadings --mountpoint "${TARGETS[I]}" > /dev/null 2>&1; then
      mount "${TARGETS[I]}"
    fi
  done
}

# Connects this machine to the repository when it is not connected yet.
connect_repository() {
  if kopia repository status > /dev/null 2>&1; then
    return 0
  fi

  if ! kopia repository connect "${DESTINATION_ARGS[@]}" --no-check-for-updates; then
    echo "cannot connect to the kopia repository at the configured destination" >&2
    echo "if the repository does not exist there yet, create it once with: ${0##*/} create" >&2
    exit 1
  fi

  JUST_CONNECTED=1
}

# Applies the retention and traversal settings from the pillar to the global policy, and makes read errors fatal for whatever is read out of the snapshot.
#
# Read errors are ignored globally because files which change or disappear while being read are normal on a running system, and a single unreadable log or
# database file must not throw away the whole snapshot. Kopia still counts them and warns about them in its summary, so they end up in the cron mail.
#
# Kopia counts every "policy set" as a change and writes a new policy manifest even when the values are identical, so this is not run on every backup, only when
# connecting for the first time and from the weekly job.
apply_policy() {
  kopia policy set --global \
    "--keep-latest=$BACKUP_KEEP_LATEST" \
    "--keep-hourly=$BACKUP_KEEP_HOURLY" \
    "--keep-daily=$BACKUP_KEEP_DAILY" \
    "--keep-weekly=$BACKUP_KEEP_WEEKLY" \
    "--keep-monthly=$BACKUP_KEEP_MONTHLY" \
    "--keep-annual=$BACKUP_KEEP_ANNUAL" \
    --ignore-file-errors=true \
    --ignore-cache-dirs=false \
    --compression=zstd-fastest

  # What is read from the snapshot cannot change while it is being read, so an error under this path is a real one, and it fails the run instead of being counted
  # and passed over. The snapshot is still written, so what could be read is kept, and the non-zero exit is what turns the rest into cron mail.
  if [ "$LVM_ENABLED" = 1 ]; then
    kopia policy set "$BACKUP_LVM_MOUNTPOINT" \
      --ignore-file-errors=false \
      --ignore-dir-errors=false
  fi
}

# Creates the repository at the configured destination and connects this machine to it.
create_repository() {
  if kopia repository status > /dev/null 2>&1; then
    echo "this machine is already connected to a repository, run \"kopia repository disconnect\" first if you really mean to create another one" >&2
    exit 1
  fi

  # Kopia refuses to create a repository where one already exists, so an existing destination is not silently overwritten here.
  kopia repository create "${DESTINATION_ARGS[@]}" --no-check-for-updates

  apply_policy

  echo
  kopia repository validate-provider

  echo
  echo "repository created and connected, maintenance owner is:"
  kopia maintenance info | grep --ignore-case '^owner:'
}

# Reports how full the destination is, and fails when it has gone past the configured share of its capacity.
check_destination_space() {
  local USED

  case "$BACKUP_DESTINATION_TYPE" in
    filesystem)
      USED=$(df --output=pcent "$BACKUP_DESTINATION_PATH" 2> /dev/null | tail -1 | tr --delete --complement '0-9')
      ;;

    sftp)
      # The percentage is picked out by looking for the field ending in a percent sign, because sftp echoes the command it was given before the table itself.
      USED=$(sftp -b - -P "$BACKUP_SFTP_PORT" -i "$SFTP_KEY_FILE" -o "UserKnownHostsFile=$SFTP_KNOWN_HOSTS_FILE" -o BatchMode=yes \
        "$BACKUP_SFTP_USERNAME@$BACKUP_SFTP_HOST" <<< df 2> /dev/null | awk '$NF ~ /%$/ { gsub(/%/, "", $NF); print $NF; exit }')
      ;;
  esac

  if [ -z "$USED" ]; then
    logger --tag backup "destination did not report how full it is"

    return 0
  fi

  logger --tag backup "destination is $USED% full"

  if [ "$USED" -ge "$BACKUP_DESTINATION_FULL_PERCENT" ]; then
    echo "the destination is $USED% full, at or above the $BACKUP_DESTINATION_FULL_PERCENT% it is meant to stay below" >&2

    return 1
  fi
}

# Runs the scripts collecting additional data to back up. A failing collection script does not prevent the snapshot, because a backup missing one of the
# collected files is much better than no backup at all. The failure is remembered and reported through the exit status, so it still produces cron mail.
run_scripts() {
  mkdir --parents "$DATA_DIR"

  local SCRIPT SCRIPT_START

  while read -r SCRIPT; do
    SCRIPT_START=$(now_ms)

    if "$SCRIPT"; then
      logger --tag backup "${SCRIPT##*/} took $(fmt_ms $(($(now_ms) - SCRIPT_START)))"
    else
      SCRIPTS_FAILED=1
      logger --tag backup "${SCRIPT##*/} failed after $(fmt_ms $(($(now_ms) - SCRIPT_START)))"
    fi
  done < <(run-parts --list "$SCRIPTS_DIR")
}

# Removes the snapshot volume. The mount of it lives in a mount namespace which is already gone by the time this runs, but device-mapper can take a moment to
# release the device afterwards, so the removal is retried before it is given up on.
remove_snapshot() {
  local ATTEMPT ERROR

  for ATTEMPT in 1 2 3 4 5; do
    if ERROR=$(lvremove --yes "$SNAPSHOT_DEVICE" 2>&1 > /dev/null); then
      SNAPSHOT_CREATED=0
      return 0
    fi

    sleep 2
  done

  echo "cannot remove the snapshot volume $SNAPSHOT_DEVICE: $ERROR" >&2
  echo "the next run removes it, until then it keeps filling up with the writes the origin volume receives" >&2

  return 1
}

# Creates the snapshot of the volume being backed up, after clearing away one left behind by a run which died without cleaning up. Removing that one is safe
# because the lock this script holds guarantees no other run is using it.
#
# Creating a snapshot suspends the origin volume, which freezes the filesystem mounted on it and flushes its pending writes, so what the snapshot holds is a
# consistent filesystem image rather than one which has to be repaired before it can be read.
create_snapshot() {
  if lvs "$SNAPSHOT_DEVICE" > /dev/null 2>&1; then
    echo "removing $SNAPSHOT_DEVICE left behind by an earlier run" >&2
    remove_snapshot
  fi

  lvcreate --snapshot --size "$BACKUP_LVM_SNAPSHOT_SIZE" --name "$SNAPSHOT_LV" "$ORIGIN_DEVICE" > /dev/null
  SNAPSHOT_CREATED=1
}

# Logs how much of the snapshot's copy-on-write area was used, and fails when the snapshot was invalidated.
#
# The area only has to hold the blocks which change on the origin volume while the backup runs. If it does fill up the kernel invalidates the snapshot and every
# read from it fails, so logging the fill level on every run is what turns "the area is large enough" from an assumption into something observable.
report_snapshot_usage() {
  local ATTR USAGE

  read -r ATTR USAGE < <(lvs --noheadings --options lv_attr,data_percent "$SNAPSHOT_DEVICE")

  logger --tag backup "snapshot copy-on-write area ${USAGE}% used"

  # The fifth character of the attributes is the state of the volume, where "I" marks a snapshot the kernel has invalidated.
  if [ "${ATTR:4:1}" = I ]; then
    echo "the snapshot ran out of copy-on-write space and was invalidated, so this backup is incomplete" >&2
    echo "raise backup:lvm:snapshot_size in the pillar, it is currently $BACKUP_LVM_SNAPSHOT_SIZE" >&2

    return 1
  fi
}

# Runs kopia with the snapshot mounted where the origin volume is normally mounted, so that the paths recorded in the backup are the ones the system really uses
# and a restore does not have to be rewritten.
#
# The mount is made inside a private mount namespace, which keeps it invisible to the rest of the machine and, more importantly, makes it disappear together
# with the namespace however the run ends, including when kopia is killed outright. Nothing has to unmount it. The PID namespace is there so that a process left
# behind inside cannot hold the namespace, and through it the snapshot volume, open after kopia is done.
snapshot_into_repository() {
  unshare --mount --pid --fork --kill-child --propagation private -- \
    bash -c 'mount --read-only "$1" "$2" || exit 1; shift 2; exec "$@"' \
    backup-snapshot "$SNAPSHOT_DEVICE" "$BACKUP_LVM_MOUNTPOINT" \
    kopia "${QUIET_FLAGS[@]}" snapshot create "$BACKUP_SOURCE"
}

# Snapshots the configured source into the repository, reading from a frozen copy of the volume when one is configured.
take_snapshot() {
  if [ "$LVM_ENABLED" = 0 ]; then
    kopia "${QUIET_FLAGS[@]}" snapshot create "$BACKUP_SOURCE"

    return
  fi

  local STATUS=0

  create_snapshot
  snapshot_into_repository || STATUS=$?

  # Checked before the snapshot is removed, and also when kopia has already failed, because a full copy-on-write area might be the reason for it to fail.
  if ! report_snapshot_usage && [ "$STATUS" = 0 ]; then
    STATUS=1
  fi

  remove_snapshot

  return "$STATUS"
}

case "$MODE" in
  create)
    if [ "$KOPIA_ENABLED" = 0 ]; then
      echo "no backup destination is configured in $CONFIG_FILE" >&2
      exit 1
    fi

    set_destination_args
    ensure_destination_mounted
    create_repository
    ;;

  backup)
    run_scripts

    if [ "$KOPIA_ENABLED" = 1 ]; then
      set_destination_args
      ensure_destination_mounted
      connect_repository

      if [ "$JUST_CONNECTED" = 1 ]; then
        apply_policy
      fi

      SNAPSHOT_START=$(now_ms)
      take_snapshot
      logger --tag backup "snapshot took $(fmt_ms $(($(now_ms) - SNAPSHOT_START)))"

      touch "$STAMP_FILE"
    fi

    exit "$SCRIPTS_FAILED"
    ;;

  verify)
    if [ "$KOPIA_ENABLED" = 0 ]; then
      exit 0
    fi

    set_destination_args
    ensure_destination_mounted
    connect_repository
    apply_policy

    # Walks every snapshot and checks that all the contents it references are present in the repository, and additionally downloads and re-hashes a sample of
    # the files, which is the part that catches silent corruption at the destination rather than just a missing blob.
    kopia snapshot verify \
      "--verify-files-percent=$BACKUP_VERIFY_FILES_PERCENT" \
      "--max-errors=$BACKUP_VERIFY_MAX_ERRORS"

    # Kopia runs maintenance on its own after every snapshot, but only on the machine recorded as the maintenance owner, and it stays silent when this machine
    # is not the owner. Running it explicitly makes a wrong owner visible as an error instead of as space which never gets reclaimed.
    #
    # It runs after the verification and not before it on purpose. Full maintenance deletes blobs which no snapshot refers to any more, and that is the last
    # thing which should happen to a repository that has just been reported as damaged.
    kopia maintenance run --full

    # Checked last, so that what it reports is the space left after maintenance has reclaimed what the expired snapshots were holding.
    check_destination_space
    ;;
esac
