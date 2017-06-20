debsums:
  pkg.latest:
    - refresh: True

debsums-init:
  cmd.wait:
    - name: apt-get clean && debsums_init
    - watch:
      - pkg: debsums

/etc/default/debsums:
  file.managed:
    - source: salt://core/debsums.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: debsums

# A package with unexplainable debsums mismatches,
# but it is not needed so we just remove it.
module-init-tools:
  pkg.purged

/etc/cron.daily/01debsums-fix:
  file.managed:
    - source: salt://core/debsums-fix.sh
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: debsums
