apt-transport-https:
  pkg.latest:
    - refresh: True

ca-certificates:
  pkg.latest:
    - refresh: True

{% if salt['pillar.get']('docker:release', None) == 'docker-ce' %}

docker-package:
  pkg.removed:
    - name: docker

docker-engine-unhold:
  cmd.run:
    - name: apt-mark unhold docker-engine

docker-engine:
  pkg.removed:
    - require:
      - cmd: docker-engine-unhold

docker.io:
  pkg.removed

docker-repository:
  pkgrepo.managed:
    - name: deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable
    - file: /etc/apt/sources.list.d/docker-repository.list
    - key_url: https://download.docker.com/linux/ubuntu/gpg
    - require_in:
      - pkg: docker-ce

docker-ce:
  pkg.installed:
    - version: 17.09.1~ce-0~ubuntu
    - refresh: True
    - hold: True

{% else %}

docker-repository:
  pkgrepo.managed:
    {% if grains['oscodename'] == 'xenial' %}
    - name: deb https://apt.dockerproject.org/repo ubuntu-xenial main
    {% elif grains['oscodename'] == 'trusty' %}
    - name: deb https://apt.dockerproject.org/repo ubuntu-trusty main
    {% endif %}
    - keyid: 58118E89F3A912897C070ADBF76221572C52609D
    - keyserver: keyserver.ubuntu.com
    - require_in:
      - pkg: docker-engine

docker-engine:
  pkg.installed:
    {% if grains['oscodename'] == 'xenial' %}
    - version: 1.12.5-0~ubuntu-xenial
    {% elif grains['oscodename'] == 'trusty' %}
    - version: 1.8.3-0~trusty
    {% endif %}
    - refresh: True
    - hold: True

{% endif %}

docker-py:
  pip.installed:
    - name: docker-py==1.10.6
    - reload_modules: True
    - require:
      - sls: pip

docker-compose:
  pip.installed:
    # We use an older version of Docker compose because a newer one depends on 2.0 version of docker-py.
    - name: docker-compose<1.10.0
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

docker-configuration-file:
  file.managed:
    {% if grains['oscodename'] == 'xenial' %}
    - name: /etc/systemd/system/docker.service.d/10-execstart.conf
    - source: salt://docker/10-execstart.conf
    {% elif grains['oscodename'] == 'trusty' %}
    - name: /etc/default/docker
    - source: salt://docker/docker.conf
    {% endif %}
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - require:
      {% if salt['pillar.get']('docker:release', None) == 'docker-ce' %}
      - pkg: docker-ce
      {% else %}
      - pkg: docker-engine
      {% endif %}

docker:
  service.running:
    - require:
      - file: /srv/docker
      - file: /srv/tmp/docker
      - file: /srv/log
      - file: /srv/repositories
    - watch:
      - file: docker-configuration-file

docker-available:
  cmd.run:
    - name: while ! docker ps; do sleep 1; done >/dev/null
    - timeout: 15
    - require:
      - service: docker

container-from-pid:
  file.managed:
    - name: /usr/local/bin/container-from-pid
    - source: salt://docker/container-from-pid.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
