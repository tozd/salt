log-rotate-workaround:
  file.managed:
    - name: /usr/local/bin/log-rotate-workaround
    - source: salt://docker/log-rotate-workaround.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: true
    - require:
      - file: container-from-pid

log-rotate-workaround-check:
  cron.present:
    - identifier: log-rotate-workaround-check
    - name: /usr/local/bin/log-rotate-workaround
    - user: root
    - minute: '*/5'
    - require:
      - file: log-rotate-workaround
