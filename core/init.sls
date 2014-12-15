en_US.UTF-8:
  locale.system

kernel.panic:
  sysctl.present:
    - value: 10

net.ipv4.ip_forward:
  sysctl.present:
    - value: 1

net.ipv6.conf.all.forwarding:
  sysctl.present:
    - value: 1

net.ipv6.conf.default.forwarding:
  sysctl.present:
    - value: 1

net.ipv4.conf.all.send_redirects:
  sysctl.present:
    - value: 0

net.ipv4.conf.all.rp_filter:
  sysctl.present:
    - value: 0

net.ipv4.conf.default.send_redirects:
  sysctl.present:
    - value: 0

net.ipv4.conf.default.rp_filter:
  sysctl.present:
    - value: 0

sysfsutils:
  pkg:
    - installed
  service.running:
    - require:
      - pkg: sysfsutils

debsums:
  pkg:
    - installed

debsums-init:
  cmd.wait:
    - name: apt-get clean && debsums_init
    - watch:
      - pkg: debsums

/etc/default/debsums:
  file.managed:
    - source: salt://core/debsums.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: debsums

unattended-upgrades:
  pkg.installed

/etc/apt/apt.conf.d/20auto-upgrades:
  file.managed:
    - source: salt://core/20auto-upgrades
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

screen:
  pkg.installed

screenrc-scrollback:
  file.replace:
    - name: /etc/screenrc
    - pattern: "^defscrollback 1024"
    - repl: defscrollback 10000
    - require:
      - pkg: screen

screenrc-block:
  file.blockreplace:
    - name: /etc/screenrc
    - marker_start: "# START screenrc-block GENERATED BY SALT. DO NOT EDIT."
    - marker_end: "# END screenrc-block"
    - content: |
        startup_message off
        defobuflimit 2048
        termcapinfo xterm|xterms|xs|rxvt ti@:te@
    - append_if_not_found: True
    - require:
      - pkg: screen

htop:
  pkg.installed

iotop:
  pkg.installed

sysstat:
  pkg.installed

iptraf:
  pkg.installed

tcpdump:
  pkg.installed

inputrc-history:
  file.blockreplace:
    - name: /etc/inputrc
    - marker_start: "# START inputrc-history GENERATED BY SALT. DO NOT EDIT."
    - marker_end: "# END inputrc-history"
    - content: |
        "\e[5~": history-search-backward
        "\e[6~": history-search-forward
    - append_if_not_found: True

ntp:
  pkg.installed

ntp-service:
  service.running:
    - name: ntp
    - require:
      - pkg: ntp
