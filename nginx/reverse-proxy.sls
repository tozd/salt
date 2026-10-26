single-host-reverse-proxy-image:
  docker_image.present:
    - name: registry.gitlab.com/tozd/docker/nginx-proxy
    - tag: ubuntu-resolute
    - force: true
    - require:
      - service: docker-service

/srv/nginx/log:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: true

/srv/nginx/dockergen:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: true

/srv/nginx/letsencrypt:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: true

/srv/nginx/dnsmasq:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: true

/srv/nginx/ssl:
  file.directory:
    - user: root
    - group: root
    - mode: 701
    - makedirs: true

/srv/nginx/sites:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

single-host-reverse-proxy-container:
  docker_container.running:
    - name: single-host-reverse-proxy
    - hostname: single-host-reverse-proxy
    - image: registry.gitlab.com/tozd/docker/nginx-proxy:ubuntu-resolute
    - environment:
      - MAILTO: "{{ pillar['mailer']['root_alias'] | join(',') }}"
      - REMOTES: "{{ pillar['mailer']['relay'] }}"
      - LETSENCRYPT_EMAIL: "{{ salt['pillar.get']('nginx:lets_encrypt_email', '') }}"
    - restart_policy: always
    - binds:
      - /srv/nginx/log:/var/log/nginx
      - /srv/nginx/dockergen:/var/log/dockergen
      - /srv/nginx/letsencrypt:/var/log/letsencrypt
      - /srv/nginx/dnsmasq:/var/log/dnsmasq
      - /srv/nginx/ssl:/ssl
      - /srv/nginx/sites:/etc/nginx/sites-volume
      - /var/run/docker.sock:/var/run/docker.sock
    - skip_translate: port_bindings
    - port_bindings:
        80/tcp:
        - HostIp: "{{ pillar['network']['address'] }}"
          HostPort: 80
        443/tcp:
        - HostIp: "{{ pillar['network']['address'] }}"
          HostPort: 443
    - require:
      - docker_image: single-host-reverse-proxy-image
      - file: /srv/nginx/log
      - file: /srv/nginx/dockergen
      - file: /srv/nginx/letsencrypt
      - file: /srv/nginx/dnsmasq
      - file: /srv/nginx/ssl
      - file: /srv/nginx/sites

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
    - save: true
    - require:
      - pkg: iptables
