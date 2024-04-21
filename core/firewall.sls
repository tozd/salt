iptables:
  pkg.latest:
    - pkgs:
      - iptables
      - iptables-persistent
    - refresh: True
    - cache_valid_time: 600
    - reload_modules: True

iptables-allow-localhost-ipv4-1:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 127.0.0.1/8
    - save: True
    - require:
      - pkg: iptables

iptables-allow-localhost-ipv6-1:
  iptables.append:
    - table: filter
    - family: ipv6
    - chain: INPUT
    - jump: ACCEPT
    - source: '::1'
    - save: True
    - require:
      - pkg: iptables

iptables-allow-localhost-ipv4-2:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - if: lo
    - save: True
    - require:
      - pkg: iptables

iptables-allow-localhost-ipv6-2:
  iptables.append:
    - table: filter
    - family: ipv6
    - chain: INPUT
    - jump: ACCEPT
    - if: lo
    - save: True
    - require:
      - pkg: iptables

iptables-allow-established-ipv4:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - match: conntrack
    - ctstate: 'RELATED,ESTABLISHED'
    - save: True
    - require:
      - pkg: iptables

iptables-allow-established-ipv6:
  iptables.append:
    - table: filter
    - family: ipv6
    - chain: INPUT
    - jump: ACCEPT
    - match: conntrack
    - ctstate: 'RELATED,ESTABLISHED'
    - save: True
    - require:
      - pkg: iptables

iptables-allow-icmp-ipv4:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - proto: icmp
    - save: True
    - require:
      - pkg: iptables

iptables-allow-icmp-ipv6:
  iptables.append:
    - table: filter
    - family: ipv6
    - chain: INPUT
    - jump: ACCEPT
    - proto: ipv6-icmp
    - save: True
    - require:
      - pkg: iptables

iptables-reject-policy:
  iptables.set_policy:
    - table: filter
    - chain: INPUT
    - policy: DROP
    - require:
      - iptables: iptables-allow-localhost-ipv4-1
      - iptables: iptables-allow-localhost-ipv6-1
      - iptables: iptables-allow-localhost-ipv4-2
      - iptables: iptables-allow-localhost-ipv6-2
      - iptables: iptables-allow-established-ipv4
      - iptables: iptables-allow-established-ipv6
