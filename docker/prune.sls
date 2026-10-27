# Daily removal of Docker images and volumes which no container uses.
docker-prune:
  file.managed:
    - name: /usr/local/bin/docker-prune
    - source: salt://docker/prune.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: true

docker-prune-daily:
  cron.present:
    - identifier: docker-prune-daily
    - name: /usr/local/bin/docker-prune
    - user: root
    - minute: 47
    - hour: 4
    - require:
      - file: docker-prune
