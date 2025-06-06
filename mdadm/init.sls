mdadm:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
    - require:
      - sls: mailer

mdadm-service:
  service.running:
    - name: mdmonitor
    - enable: true
    - watch:
      - pkg: mdadm
