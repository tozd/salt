smartmontools:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600

/etc/smartd.conf:
  file.managed:
    - source: salt://smart/smartd.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: smartmontools

smartmontools-service:
  service.running:
    - name: smartmontools
    - enable: True
    - watch:
      - pkg: smartmontools
      - file: /etc/smartd.conf
