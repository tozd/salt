{% set kopia_version = '0.23.1' %}
{% set kopia_hash = '416d0f84a3dbb321a8b2d8f0997b1a0a6e915babe79ee76fa6e4d2bd1e1c5178' %}

{% set backup = salt['pillar.get']('backup', {}) %}
{% set destination = backup.get('destination', {}) %}
{% set retention = backup.get('retention', {}) %}
{% set lvm = backup.get('lvm', {}) %}

dmidecode:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

efibootmgr:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

pciutils:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

lshw:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

debconf-utils:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
{% if lvm %}

lvm2:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
{% endif %}

kopia-archive:
  archive.extracted:
    - name: /usr/local/lib
    - source: https://github.com/kopia/kopia/releases/download/v{{ kopia_version }}/kopia-{{ kopia_version }}-linux-x64.tar.gz
    - source_hash: sha256={{ kopia_hash }}
    - user: root
    - group: root
    - if_missing: /usr/local/lib/kopia-{{ kopia_version }}-linux-x64/kopia

/usr/local/bin/kopia:
  file.symlink:
    - target: /usr/local/lib/kopia-{{ kopia_version }}-linux-x64/kopia
    - force: true
    - require:
      - archive: kopia-archive

/etc/profile.d/kopia.sh:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------

        # Only root can read any of these, and pointing another user at them turns a clear "not connected" into a permission error.
        if [ "$(id -u)" = 0 ]; then
          export KOPIA_CONFIG_PATH=/var/lib/kopia/repository.config
          export KOPIA_CACHE_DIRECTORY=/var/cache/kopia
          export KOPIA_LOG_DIR=/var/log/kopia
          export KOPIA_CHECK_FOR_UPDATES=false
        fi
    - user: root
    - group: root
    - mode: 644

# Data prepared for the backup by the scripts in /etc/backup.d.
/srv/backup:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

# Scripts run before the snapshot is taken. They write into /srv/backup and are run in filename order by run-parts, so the numeric prefixes decide the order.
# A failing script does not prevent the snapshot, but failure is reported through the exit status, so it still produces cron e-mail.
#
# The directory is deliberately not cleaned, so that other states can add scripts of their own for the data only they know how to collect. Those states should
# require this one, and should number their scripts above 50 so that they run after the ones shipped here.
/etc/backup.d:
  file.recurse:
    - source: salt://backup/backup.d
    - user: root
    - group: root
    - dir_mode: 700
    - file_mode: 755

/var/lib/kopia:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/var/cache/kopia:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/var/log/kopia:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/usr/local/sbin/backup:
  file.managed:
    - source: salt://backup/backup.sh
    - user: root
    - group: root
    - mode: 755

/.kopiaignore:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------

        # The pseudo filesystems.
        /proc
        /sys
        /dev
        /run

        # Additional exclusions.
        /mnt
        /media

        # Temporary directories.
        /tmp
        /var/tmp
        /srv/tmp

        # Filesystem recovery directories.
        lost+found/

        # Caches.
        /var/cache/*
        /var/lib/apt/lists
        /var/lib/plocate
        /root/.cache

        # Answers given to package configuration prompts.
        !/var/cache/debconf/

        # Docker images and container layers.
        /srv/docker/*
        /srv/containerd
        /var/lib/docker
        /var/lib/containerd

        # Container logs and configurations.
        !/srv/docker/containers/
        /srv/docker/containers/*/mounts
        /srv/docker/containers/*/checkpoints

        # Swap, which is a copy of memory contents.
        /swap.img
        /var/swap
        {%- if destination.get('type') == 'filesystem' and destination.get('path') %}

        # The backup destination itself.
        {{ destination['path'] }}
        {%- endif %}
    - user: root
    - group: root
    - mode: 644

{% if destination.get('type') == 'sftp' %}
/etc/kopia:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/etc/kopia/sftp_key:
  file.managed:
    # It carries no header comment because OpenSSH parses the key format strictly.
    - contents_pillar: backup:destination:key
    - user: root
    - group: root
    - mode: 600
    - show_changes: false
    - require:
      - file: /etc/kopia

# Use "ssh-keyscan -p <port> <host>" to obtain the host keys.
/etc/kopia/sftp_known_hosts:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------
        {{ destination['known_hosts'] | indent(8) }}
    - user: root
    - group: root
    - mode: 600
    - require:
      - file: /etc/kopia
{% endif %}

{% if backup %}
/etc/backup.conf:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------

        KOPIA_PASSWORD='{{ backup['password'] }}'

        BACKUP_SOURCE='{{ backup.get('source', '/') }}'

        BACKUP_DESTINATION_TYPE='{{ destination['type'] }}'
        BACKUP_DESTINATION_PATH='{{ destination.get('path', '') }}'

        BACKUP_SFTP_HOST='{{ destination.get('host', '') }}'
        BACKUP_SFTP_PORT='{{ destination.get('port', 22) }}'
        BACKUP_SFTP_USERNAME='{{ destination.get('username', '') }}'
        BACKUP_SFTP_PATH='{{ destination.get('path', '') }}'

        BACKUP_LVM_VOLUME_GROUP='{{ lvm.get('volume_group', '') }}'
        BACKUP_LVM_LOGICAL_VOLUME='{{ lvm.get('logical_volume', '') }}'
        BACKUP_LVM_SNAPSHOT_SIZE='{{ lvm.get('snapshot_size', '') }}'
        BACKUP_LVM_MOUNTPOINT='{{ lvm.get('mountpoint', '') }}'

        BACKUP_KEEP_LATEST='{{ retention.get('keep_latest', 10) }}'
        BACKUP_KEEP_HOURLY='{{ retention.get('keep_hourly', 48) }}'
        BACKUP_KEEP_DAILY='{{ retention.get('keep_daily', 14) }}'
        BACKUP_KEEP_WEEKLY='{{ retention.get('keep_weekly', 8) }}'
        BACKUP_KEEP_MONTHLY='{{ retention.get('keep_monthly', 24) }}'
        BACKUP_KEEP_ANNUAL='{{ retention.get('keep_annual', 3) }}'

        BACKUP_DESTINATION_FULL_PERCENT='{{ backup.get('destination_full_percent', 95) }}'

        BACKUP_VERIFY_FILES_PERCENT='{{ backup.get('verify_files_percent', 1) }}'
        BACKUP_VERIFY_MAX_ERRORS='{{ backup.get('verify_max_errors', 100) }}'
    - user: root
    - group: root
    - mode: 600
    - show_changes: false
{% else %}
/etc/backup.conf:
  file.absent
{% endif %}

# The backup runs after the weekly verification run (but it might be skipped if verification still holds a lock).
/etc/cron.d/backup:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------

        MAILTO={{ pillar['mailer']['root_alias'] | join(',') }}

        23 * * * *	root	/usr/local/sbin/backup
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /usr/local/sbin/backup

/etc/cron.d/backup-verify:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------

        MAILTO={{ pillar['mailer']['root_alias'] | join(',') }}

        13 1 * * 0	root	/usr/local/sbin/backup verify
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /usr/local/sbin/backup
