mdadm:
  pkg.installed:
    - require:
      - sls: mailer
  service.running:
    - watch:
      - pkg: mdadm
