/srv/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/srv/tmp/docker:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/srv/repositories:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

/srv/storage:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: true

container-from-pid:
  file.managed:
    - name: /usr/local/bin/container-from-pid
    - source: salt://docker/container-from-pid.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: true
