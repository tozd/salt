lm-sensors:
  pkg.latest:
    - refresh: True

sensord:
  pkg.latest:
    - refresh: True
    - require:
      - pkg: lm-sensors
