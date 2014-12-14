/etc/hostname:
  file.managed:
    - contents_pillar: network:system:hostname
    - mode: 644
    - user: root
    - group: root

/etc/hosts:
  file.managed:
    - source: salt://network/hosts
    - template: jinja
    - mode: 644
    - user: root
    - group: root

/etc/network/interfaces:
  file.managed:
    - source: salt://network/interfaces
    - template: jinja
    - mode: 644
    - user: root
    - group: root
