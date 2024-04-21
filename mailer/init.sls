exim4:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600

exim4-service:
  service.running:
    - name: exim4
    - enable: True
    - watch:
      - pkg: exim4

/etc/mailname:
  file.managed:
    - contents_pillar: network:system:fqdn
    - mode: 644
    - user: root
    - group: root
    - require:
      - file: /etc/hostname

/etc/exim4/update-exim4.conf.conf:
  file.managed:
    - source: salt://mailer/update-exim4.conf
    - template: jinja
    - mode: 644
    - user: root
    - group: root
    - watch:
      - pkg: exim4

update-exim:
  cmd.wait:
    - name: /usr/sbin/update-exim4.conf
    - watch:
      - file: /etc/exim4/update-exim4.conf.conf
      - file: /etc/mailname
    - watch_in:
      - service: exim4

{% if salt['pillar.get']('mailer:root_alias', None) %}
root:
  alias.present:
    - target: '{{ pillar['mailer']['root_alias']|join(',') }}'
    - require:
      - pkg: exim4
{% endif %}
