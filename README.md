Currently we support Ubuntu Server 16.04 installed on the server, but it might work with newer
versions as well.

Install `salt-ssh` using `virtualenv`:

```bash
# Create a virtualenv, for example:
$ virtualenv salt-virtualenv
$ source salt-virtualenv/bin/activate

# Install salt==2016.11.1
$ pip install salt==2016.11.1

# Check version of salt-ssh
$ salt-ssh --version
# salt-ssh 2016.11.1 (Carbon)
```

We are currently using an old version of Salt (2016.11.1).
