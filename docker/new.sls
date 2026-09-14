docker.io:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
    - require:
      - file: docker-configuration-file
      - file: docker-service-file
      - file: docker-require-srv-file

docker-buildx:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

python3-docker:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
    - reload_modules: true

docker-configuration-file:
  file.managed:
    - name: /etc/docker/daemon.json
    - source: salt://docker/daemon.json
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

docker-service-file:
  file.managed:
    - name: /etc/systemd/system/docker.service.d/10-execstart.conf
    - source: salt://docker/10-execstart-new.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

docker-require-srv-file:
  file.managed:
    - name: /etc/systemd/system/docker.service.d/20-require-srv.conf
    - source: salt://docker/require-srv.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

containerd-configuration-file:
  file.managed:
    - name: /etc/containerd/config.toml
    - source: salt://docker/containerd.toml
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

containerd-require-srv-file:
  file.managed:
    - name: /etc/systemd/system/containerd.service.d/10-require-srv.conf
    - source: salt://docker/require-srv.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

containerd-service:
  service.running:
    - name: containerd
    - enable: true
    - require:
      - file: /srv/containerd
    - watch:
      - file: containerd-configuration-file
      - file: containerd-require-srv-file

# Docker restarts whenever containerd does, because dockerd holds a connection to it which does not survive containerd being restarted underneath it.
docker-service:
  service.running:
    - name: docker
    - enable: true
    - require:
      - file: /srv/docker
      - file: /srv/tmp/docker
      - file: /srv/repositories
      - file: /srv/storage
      - service: containerd-service
    - watch:
      - pkg: docker.io
      - file: docker-configuration-file
      - file: docker-service-file
      - file: docker-require-srv-file
      - file: containerd-configuration-file
      - file: containerd-require-srv-file

include:
  - .files
