/etc/hostname:
  file.managed:
    - contents_pillar: network:system:hostname
    - mode: 644
    - user: root
    - group: root

hostname-init:
  cmd.wait:
    - name: hostnamectl set-hostname {{ pillar['network']['system']['hostname'] }}
    - watch:
      - file: /etc/hostname

/etc/hosts:
  file.managed:
    - source: salt://netplan/hosts
    - template: jinja
    - mode: 644
    - user: root
    - group: root

/etc/netplan/01-netcfg.yaml:
  file.managed:
    - source: salt://netplan/netcfg.yaml
    - template: jinja
    - mode: 600
    - user: root
    - group: root

netplan.io:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600

netplan-init:
  cmd.wait:
    - name: netplan apply
    - require:
      - pkg: netplan.io
    - watch:
      - file: /etc/netplan/01-netcfg.yaml
