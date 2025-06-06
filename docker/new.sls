docker.io:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
    - require:
      - file: docker-configuration-file
      - file: docker-service-file

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

docker-service:
  service.running:
    - name: docker
    - enable: true
    - require:
      - file: /srv/docker
      - file: /srv/tmp/docker
      - file: /srv/repositories
      - file: /srv/storage
    - watch:
      - pkg: docker.io
      - file: docker-configuration-file
      - file: docker-service-file

include:
  - .files
