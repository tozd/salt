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

/etc/cron.daily/01debsums-fix:
  file.managed:
    - source: salt://core/debsums-fix.sh
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: debsums
