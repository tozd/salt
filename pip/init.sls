python-setuptools:
  pkg.installed

python-pip:
  cmd.run:
    - name: easy_install pip
    - unless: which pip
    - require:
      - pkg: python-setuptools
    - reload_modules: True
