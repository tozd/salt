/etc/hostname:
  file.managed:
    - contents_pillar: network:system:hostname
    - mode: 644
    - user: root
    - group: root

hostname-init:
  cmd.wait:
{% if grains['oscodename'] == 'xenial' %}
    - name: /etc/init.d/hostname.sh start
{% elif grains['oscodename'] == 'trusty' %}
    - name: service hostname start
{% endif %}
    - watch:
      - file: /etc/hostname

/etc/hosts:
  file.managed:
    - source: salt://network/hosts
    - template: jinja
    - mode: 644
    - user: root
    - group: root

/etc/network/interfaces:
  file.managed:
    - source: salt://network/interfaces
    - template: jinja
    - mode: 644
    - user: root
    - group: root
