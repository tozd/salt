apt-transport-https:
  pkg.latest:
    - refresh: True

ca-certificates:
  pkg.latest:
    - refresh: True

docker-repository:
  pkgrepo.managed:
    - humanname: Docker
    - name: deb https://apt.dockerproject.org/repo ubuntu-xenial main
    - keyid: 58118E89F3A912897C070ADBF76221572C52609D
    - keyserver: keyserver.ubuntu.com
    - require_in:
      - pkg: docker-engine

docker-engine:
  pkg.installed:
    - name: docker-engine
    - version: 1.12.5-0~ubuntu-xenial
    - refresh: True
    - hold: True

docker-py:
  pip.installed:
    - name: docker-py==1.10.6
    - reload_modules: True
    - require:
      - sls: pip

docker-compose:
  pip.installed:
    - require:
      - sls: pip

/srv/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

/srv/tmp/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

/srv/log:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

/srv/repositories:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

/srv/storage:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

/etc/systemd/system/docker.service.d/10-execstart.conf:
  file.managed:
    - source: salt://docker/10-execstart.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - require:
      - pkg: docker-engine

docker:
  service.running:
    - require:
      - file: /srv/docker
      - file: /srv/tmp/docker
      - file: /srv/log
      - file: /srv/repositories
    - watch:
      - file: /etc/systemd/system/docker.service.d/10-execstart.conf

docker-available:
  cmd.run:
    - name: while ! docker ps; do sleep 1; done >/dev/null
    - timeout: 15
    - require:
      - service: docker
