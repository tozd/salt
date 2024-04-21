mdadm:
  pkg.latest:
    - refresh: True
    - cache_valid_time: 600
    - require:
      - sls: mailer

mdadm-service:
  service.running:
    - name: mdmonitor
    - enable: True
    - watch:
      - pkg: mdadm
