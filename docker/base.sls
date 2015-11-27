docker-repository:
  pkgrepo.managed:
    - humanname: Docker
    - name: deb https://apt.dockerproject.org/repo ubuntu-trusty main
    - keyid: 58118E89F3A912897C070ADBF76221572C52609D
    - keyserver: keyserver.ubuntu.com
    - require_in:
      - pkg: docker-engine

docker-engine:
  pkg.installed:
    - name: docker-engine
    - version: 1.8.3-0~trusty
    - hold: True

docker-py:
  pip.installed:
    - name: docker-py==1.0.0
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

/etc/default/docker:
  file.managed:
    - source: salt://docker/docker.conf
    - user: root
    - group: root
    - mode: 644
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
      - file: /etc/default/docker

docker-available:
  cmd.run:
    - name: while ! docker ps; do sleep 1; done >/dev/null
    - timeout: 15
    - require:
      - service: docker
