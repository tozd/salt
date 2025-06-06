logwatch:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

/etc/logwatch/conf/logwatch.conf:
  file.managed:
    - source: salt://logwatch/logwatch.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: logwatch

/etc/cron.d/logwatch:
  file.managed:
    - source: salt://logwatch/logwatch.cron
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: logwatch
