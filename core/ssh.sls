openssh-client:
  pkg.latest:
    - refresh: True

openssh-server:
  pkg.latest:
    - refresh: True

ssh:
  service.running:
    - enable: True
    - require:
      - pkg: openssh-server
    - watch:
      - file: /etc/ssh/sshd_config

sshd-keepalive-client:
  file.blockreplace:
    - name: /etc/ssh/sshd_config
    - marker_start: "# START sshd_config GENERATED BY SALT. DO NOT EDIT."
    - marker_end: "# END sshd_config"
    - content: |
        ClientAliveInterval 60
        ClientAliveCountMax 15
    - append_if_not_found: True
    - require:
      - pkg: openssh-server

sshd-keepalive-tcp:
  file.replace:
    - name: /etc/ssh/sshd_config
    - pattern: "^TCPKeepAlive yes"
    - repl: TCPKeepAlive no
    - require:
      - pkg: openssh-server

mosh:
  pkg.latest:
    - refresh: True

iptables-ssh-policy:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 0.0.0.0/0
    - dport: ssh
    - proto: tcp
    - save: True
    - require:
      - pkg: iptables
    - require_in:
      - iptables: iptables-reject-policy
