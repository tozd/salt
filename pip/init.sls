python-setuptools:
  pkg.latest:
    - refresh: True

python-pip-package:
  pkg.purged:
    - name: python-pip

python-pip:
  cmd.run:
    - name: easy_install pip
    - unless: which pip
    - require:
      - pkg: python-pip-package
      - pkg: python-setuptools
    - reload_modules: True
