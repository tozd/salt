systemd-timesyncd:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

systemd-timesyncd-service:
  service.running:
    - name: systemd-timesyncd
    - enable: true
    - watch:
      - pkg: systemd-timesyncd
