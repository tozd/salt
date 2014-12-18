ntp:
  pkg.installed

ntp-service:
  service.running:
    - name: ntp
    - require:
      - pkg: ntp

iptables-ntp-policy:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 0.0.0.0/0
    - dport: ntp
    - proto: udp
    - save: True
    - require:
      - pkg: iptables
