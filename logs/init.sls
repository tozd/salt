{% set prettylog_version = '0.11.4' %}
{% set prettylog_hash = '5b9d6ddf967f449c1ab8bd0bce9a8406986490614c81363da44db1ecafdfe186' %}

# Keeping logging information for at least 6 months. This assumes Ubuntu 24.04.

# Ubuntu rotates wtmp and btmp with "rotate 1", which keeps only between one and two months, so 12 monthly rotations are kept instead.
# Rotated copies are read with "last -f /var/log/wtmp.1" and "lastb -f /var/log/btmp.1". minsize prevents a small wtmp from being
# rotated at all, which only ever extends how far back the current file reaches, so it is kept as Ubuntu has it.
/etc/logrotate.d/wtmp:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------
        /var/log/wtmp {
            missingok
            monthly
            create 0664 root utmp
            minsize 1M
            rotate 12
        }
    - user: root
    - group: root
    - mode: 644

/etc/logrotate.d/btmp:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------
        /var/log/btmp {
            missingok
            monthly
            create 0660 root utmp
            rotate 12
        }
    - user: root
    - group: root
    - mode: 644

# sshd logs the details of every login attempt (source address, user, authentication method) into /var/log/auth.log through rsyslog, where Ubuntu keeps 4 weekly
# rotations. 30 of them are about 7 months. This one stanza covers syslog, mail.log, kern.log, auth.log, user.log and cron.log together.
auth-log-retention:
  file.replace:
    - name: /etc/logrotate.d/rsyslog
    - pattern: '^([ \t]+)rotate[ \t]+[0-9]+$'
    - repl: '\g<1>rotate 30'
    - backup: false

# systemd-journald keeps its own copy of login records (systemd-logind sessions and sshd messages) and discards them by size, not by age, so the journal is made
# persistent across reboots and gets the same space as the built-in cap. SystemKeepFree (15% of the filesystem by default) still keeps it from filling the disk.
# MaxRetentionSec is deliberately not set: it is an upper bound on age and would only delete entries earlier.
/etc/systemd/journald.conf.d/retention.conf:
  file.managed:
    - contents: |
        # ------------------------------------------------------------------------
        # THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
        # ANY MANUAL CHANGES WILL BE OVERWRITTEN!
        # ------------------------------------------------------------------------
        [Journal]
        Storage=persistent
        SystemMaxUse=4G
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755

systemd-journald-service:
  service.running:
    - name: systemd-journald
    - watch:
      - file: /etc/systemd/journald.conf.d/retention.conf

/usr/local/bin/prettylog:
  file.managed:
    - source: https://gitlab.com/tozd/go/zerolog/-/releases/v{{ prettylog_version }}/downloads/linux-amd64/prettylog
    - source_hash: sha256={{ prettylog_hash }}
    - user: root
    - group: root
    - mode: 755
