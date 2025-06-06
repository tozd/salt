python-setuptools:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

{% if grains['oscodename'] == 'xenial' %}
python-pip:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600
    - reload_modules: true
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
    - reload_modules: true
{% endif %}
