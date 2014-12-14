mdadm:
  pkg.installed:
    - require:
      - sls: mailer
  service.running:
    - watch:
      - pkg: mdadm

/etc/mdadm/mdadm.conf:
  file.managed:
    - source: salt://mdadm/mdadm.conf
    - template: jinja
    - mode: 644
    - user: root
    - group: root
    - watch:
      - pkg: mdadm
    - watch_in:
      - service: mdadm
