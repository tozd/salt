single-host-reverse-proxy-image:
  docker.pulled:
    - name: tozd/nginx-proxy
    - tag: latest
    - force: True
    - require:
      - sls: docker.base

/srv/nginx/log:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/nginx/dockergen:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/nginx/letsencrypt:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/nginx/dnsmasq:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/nginx/ssl:
  file.directory:
    - user: root
    - group: root
    - mode: 701
    - makedirs: True

/srv/nginx/sites:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

single-host-reverse-proxy-container:
  docker.running:
    - name: single-host-reverse-proxy
    - hostname: single-host-reverse-proxy
    - image: tozd/nginx-proxy
    - environment:
        MAILTO: '{{ pillar['mailer']['root_alias']|join(',') }}'
        REMOTES: {{ pillar['mailer']['relay'] }}
        LETSENCRYPT_EMAIL: {{ salt['pillar.get']('nginx:lets_encrypt_email', '') }}
    - ports:
        80/tcp:
          HostIp: {{ pillar['network']['address'] }}
          HostPort: 80
        443/tcp:
          HostIp: {{ pillar['network']['address'] }}
          HostPort: 443
    - volumes:
        /srv/nginx/log:
          bind: /var/log/nginx
        /srv/nginx/dockergen:
          bind: /var/log/dockergen
        /srv/nginx/letsencrypt:
          bind: /var/log/letsencrypt
        /srv/nginx/dockergen:
          bind: /var/log/dockergen
        /srv/nginx/dnsmasq:
          bind: /var/log/dnsmasq
        /srv/nginx/ssl:
          bind: /ssl
        /srv/nginx/sites:
          bind: /etc/nginx/sites-volume
        /var/run/docker.sock:
          bind: /var/run/docker.sock
    - restart_policy:
        Name: always
    - require:
      - file: /srv/nginx/log
      - file: /srv/nginx/dockergen
      - file: /srv/nginx/letsencrypt
      - file: /srv/nginx/dockergen
      - file: /srv/nginx/dnsmasq
      - file: /srv/nginx/ssl
      - file: /srv/nginx/sites
      - docker: single-host-reverse-proxy-image

iptables-single-host-reverse-proxy-policy:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - source: 0.0.0.0/0
    - dports:
      - 80
      - 443
    - proto: tcp
    - save: True
    - require:
      - pkg: iptables
