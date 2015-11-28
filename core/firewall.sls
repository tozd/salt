iptables:
  pkg.latest:
    - pkgs:
      - iptables
      - iptables-persistent
    - refresh: True
    - reload_modules: True

iptables-allow-localhost-1:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 127.0.0.1/8
    - save: True
    - require:
      - pkg: iptables

iptables-allow-localhost-2:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - if: lo
    - save: True
    - require:
      - pkg: iptables

iptables-allow-established:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - match: conntrack
    - ctstate: 'RELATED,ESTABLISHED'
    - save: True
    - require:
      - pkg: iptables

iptables-allow-icmp:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 0.0.0.0/0
    - proto: icmp
    - save: True
    - require:
      - pkg: iptables

iptables-reject-policy:
  iptables.set_policy:
    - table: filter
    - chain: INPUT
    - policy: DROP
    - require:
      - iptables: iptables-allow-localhost-1
      - iptables: iptables-allow-localhost-2
      - iptables: iptables-allow-established
