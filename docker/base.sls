docker-repository:
  pkgrepo.managed:
    - humanname: Docker
    - name: deb https://get.docker.io/ubuntu docker main
    - keyid: 36A1D7869245C8950F966E92D8576A8BA88D21E9
    - keyserver: keyserver.ubuntu.com
    - require_in:
      - pkg: lxc-docker

lxc-docker:
  pkg.installed

docker-py:
  pip.installed:
    - require:
      - sls: pip

/srv/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/tmp/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/log:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/srv/repositories:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/etc/default/docker:
  file.managed:
    - source: salt://docker/docker.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: lxc-docker

docker:
  service.running:
    - require:
      - file: /srv/docker
      - file: /srv/tmp/docker
      - file: /srv/log
      - file: /srv/repositories
    - watch:
      - file: /etc/default/docker
