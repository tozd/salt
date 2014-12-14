smartmontools:
  pkg.installed

/etc/default/smartmontools:
  file.managed:
    - source: salt://smart/smartmontools.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: smartmontools

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
    - watch:
      - file: /etc/default/smartmontools
      - file: /etc/smartd.conf

