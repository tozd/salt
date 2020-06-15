Currently we support Ubuntu Server 16.04 installed on the server.

Install `salt-ssh` using `virtualenv`:

```bash
# Create a Python 2 virtualenv, for example:
$ virtualenv --python=python2.7 --no-site-packages salt-virtualenv
$ source salt-virtualenv/bin/activate

# Install salt and all dependencies:
$ pip install -r requirements.txt

# Check version of salt-ssh
$ salt-ssh --version
# salt-ssh 2017.7.2 (Nitrogen)
```

We are currently using an old version of Salt (2017.7.2) and Python 2.
