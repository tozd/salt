exim4:
  pkg.installed:
    - require:
      - sls: network
  service.running:
    - watch:
      - pkg: exim4

/etc/mailname:
  file.managed:
    - contents_pillar: network:system:fqdn
    - mode: 644
    - user: root
    - group: root

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
