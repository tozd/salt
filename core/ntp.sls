# There is no systemd-timesyncd package on trusty and xenial.
{% if grains['oscodename'] in ['trusty', 'xenial'] %}

ntp:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

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
    - save: true
    - require:
      - pkg: iptables

{% else %}

systemd-timesyncd:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

systemd-timesyncd-service:
  service.running:
    - name: systemd-timesyncd
    - enable: true
    - watch:
      - pkg: systemd-timesyncd

{% endif %}
