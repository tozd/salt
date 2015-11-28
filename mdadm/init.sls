mdadm:
  pkg.latest:
    - refresh: True
    - require:
      - sls: mailer
  service.running:
    - watch:
      - pkg: mdadm
