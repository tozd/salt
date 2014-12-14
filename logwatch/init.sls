logwatch:
  pkg:
    - installed

/etc/logwatch/scripts/services/kernel:
  file.managed:
    - source: salt://logwatch/scripts/kernel
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: logwatch

/etc/logwatch/scripts/services/zz-empty_space:
  file.managed:
    - source: salt://logwatch/scripts/zz-empty_space
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: logwatch

/etc/logwatch/conf/services/zz-empty_space.conf:
  file.managed:
    - source: salt://logwatch/conf/zz-empty_space.conf
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: logwatch

/etc/logwatch/conf/logwatch.conf:
  file.managed:
    - source: salt://logwatch/logwatch.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: logwatch
