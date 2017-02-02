python-setuptools:
  pkg.latest:
    - refresh: True

{% if grains['oscodename'] == 'xenial' %}
python-pip:
  pkg.latest:
    - refresh: True
    - reload_modules: True
{% elif grains['oscodename'] == 'trusty' %}
python-pip-package:
  pkg.purged:
    - name: python-pip

python-pip:
  cmd.run:
    - name: easy_install pip==8.1.1
    - unless: which pip
    - require:
      - pkg: python-pip-package
      - pkg: python-setuptools
    - reload_modules: True
{% endif %}
