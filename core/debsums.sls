debsums:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600

/etc/default/debsums:
  file.managed:
    - source: salt://core/debsums.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: debsums
