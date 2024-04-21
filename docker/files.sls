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

container-from-pid:
  file.managed:
    - name: /usr/local/bin/container-from-pid
    - source: salt://docker/container-from-pid.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
