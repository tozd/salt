# Salt states

Reusable [Salt](https://docs.saltproject.io/en/latest/contents.html) states, used as a submodule by the
repositories which deploy the actual servers.

Currently we support Ubuntu Server 22.04 or newer installed on the server.

Install `salt-ssh` using `venv`:

```bash
# Create Python3 venv.
$ python3 -m venv ~/.venv/salt
$ source ~/.venv/salt/bin/activate

# Install salt and all dependencies.
$ pip3 install -r requirements.txt

# Check version of salt-ssh, a fork from salt-ssh 3007.9 (Chlorine).
$ salt-ssh --version
salt-ssh 3007.9+10.g758e85ef2c (Chlorine)
```

Some states have a README of their own:

- [`backup`](./backup/README.md)
