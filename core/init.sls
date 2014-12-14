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

screenrc-startup-message:
  file.replace:
    - name: /etc/screenrc
    - pattern: "^#startup_message off"
    - repl: startup_message off
    - require:
      - pkg: screen

screenrc-scrollback:
  file.replace:
    - name: /etc/screenrc
    - pattern: "^defscrollback 1024"
    - repl: |
        defscrollback 10000
        defobuflimit 2048
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

inputrc-pgup:
  file.replace:
    - name: /etc/inputrc
    - pattern: '^# ".+": history-search-backward'
    - repl: '"\e[5~": history-search-backward'

inputrc-pgdn:
  file.replace:
    - name: /etc/inputrc
    - pattern: '^# ".+": history-search-forward'
    - repl: '"\e[6~": history-search-forward'
