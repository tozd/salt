unattended-upgrades:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

/etc/apt/apt.conf.d/20auto-upgrades:
  file.managed:
    - source: salt://core/20auto-upgrades
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: unattended-upgrades

/etc/apt/apt.conf.d/20auto-clean:
  file.managed:
    - source: salt://core/20auto-clean
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: unattended-upgrades

/etc/apt/apt.conf.d/50unattended-upgrades:
  file.managed:
    - source: salt://core/50unattended-upgrades
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: unattended-upgrades
