systemd-timesyncd:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600

systemd-timesyncd-service:
  service.running:
    - name: systemd-timesyncd
    - enable: True
    - watch:
      - pkg: systemd-timesyncd
