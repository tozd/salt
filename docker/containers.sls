#!pyobjects

import os
from salt.utils import pyobjects

Sls = pyobjects.StateFactory('sls')

def state(_cls, _func, _id, **kwargs):
    from salt.utils import pyobjects

    try:
        return getattr(_cls, _func)(_id, **kwargs).requisite
    except pyobjects.DuplicateState:
        return _cls(_id)

# Setup docker containers
for container, cfg in pillar('docker:containers').items():
    docker_image = state(
        Docker, 'pulled',
        '%s-image' % container,
        name=cfg['image'],
        tag=cfg.get('tag', 'latest'),
        require=Sls('docker.base'),
    )

    requires = [docker_image]
    volumes = {}

    # Create the required configs
    for cfg_name, cfg_path in cfg.get('config', {}).items():
        contents = pillar('docker:configs:%s' % cfg_name)
        if contents:
            cfg_host_path = os.path.join('/srv/storage/config', cfg_name)
            volume = state(
                File, 'managed',
                cfg_host_path,
                contents=contents,
                user='root',
                group='root',
                mode=644,
                makedirs=True,
            )
            volumes[cfg_host_path] = {
                'bind': cfg_path,
                'ro': True,
            }
            requires.append(volume)

    # Create the required volumes
    for vol_name, vol_cfg in cfg.get('volumes', {}).items():
        volumes[vol_name] = {
            'bind': vol_cfg['bind'],
            'ro': vol_cfg.get('readonly', False),
        }

        vol_type = vol_cfg.get('type', 'directory')
        if vol_type == 'directory':
            volume = state(
                File, 'directory',
                vol_name,
                user=vol_cfg.get('user', 'root'),
                group=vol_cfg.get('group', 'root'),
                mode=vol_cfg.get('mode', 755),
                makedirs=True,
            )
        elif vol_type == 'file':
            volume = state(
                File, 'managed',
                vol_name,
                user=vol_cfg.get('user', 'root'),
                group=vol_cfg.get('group', 'root'),
                mode=vol_cfg.get('mode', 644),
                makedirs=True,
            )
        elif vol_type in ('socket', 'other'):
            # Nothing should be done for sockets
            volume = None
        elif vol_type == 'container':
            # Dependency from another container
            volume = Docker('%s-container' % vol_cfg['container'])

        if volume is not None:
            requires.append(volume)

    # Setup required kernel modules on the host
    for module_name in cfg.get('host_kernel_modules', []):
        module = state(
            Kmod, 'present',
            module_name,
            name=module_name,
            persist=True,
        )
        requires.append(module)

    # Setup required sysctls on the host
    for sysctl_name, sysctl_value in cfg.get('sysctl', {}).items():
        sysctl = state(
            Sysctl, 'present',
            sysctl_name,
            value=sysctl_value,
        )
        requires.append(sysctl)

    # Setup required sysfs configuration on the host
    for sysfs_name, sysfs_value in cfg.get('sysfs', {}).items():
        sysfs = state(
            File, 'managed',
            sysfs_name,
            name='/etc/sysfs.d/%s.conf' % sysfs_name,
            contents='%s = %s' % (sysfs_name.replace('.', '/'), sysfs_value),
            watch_in=Service('sysfsutils'),
        )
        requires.append(sysfs)

    # Setup required links
    links = {}
    for link_name, link_alias in cfg.get('links', {}).items():
        requires.append(Docker('%s-container' % link_name))
        links[link_name] = link_alias

    # Setup required ports
    ports = {}
    for port_def, port_bind in cfg.get('ports', {}).items():
        ports[port_def] = {
            'HostIp': port_bind['ip'],
            'HostPort': port_bind['port'],
        }

        # Setup firewall rules
        firewall = state(
            Iptables, 'append',
            '%s-container-port-%s-%s' % (container, port_bind['ip'], port_bind['port']),
            table='filter',
            chain='INPUT',
            jump='ACCEPT',
            source='0.0.0.0/0',
            destination='%s/32' % port_bind['ip'],
            dport=port_bind['port'],
            proto='tcp' if 'tcp' in port_def else 'udp',
            save=True,
            require=Pkg('iptables'),
        )

    # Prepare the environment
    cfg_environment = cfg.get('environment', {})
    environment = []
    if isinstance(cfg_environment, dict):
        # Direct environment variable specification
        environment += [{key: value for key, value in cfg_environment.items()}]
    elif isinstance(cfg_environment, list):
        for item in cfg_environment:
            if isinstance(item, dict):
                # Direct environment variable specification
                environment += [{key: value for key, value in item.items()}]
            elif isinstance(item, basestring):
                # Reference to common environment
                item = pillar('docker:environments:%s' % item)
                environment += [{key: value for key, value in item.items()}]

    # Configure resource limits
    resources = cfg.get('resources', {})

    requires.append(state(
        Docker, 'installed',
        '%s-container-installed' % container,
        name=container,
        hostname=container,
        image='%s:%s' % (cfg['image'], cfg.get('tag', 'latest')),
        environment=environment,
        ports=ports,
        mem_limit=resources.get('memory', 0),
    ))

    network_mode = cfg.get('network_mode', None)
    if network_mode is not None and network_mode['type'] == 'container':
        requires.append(Docker('%s-container' % network_mode['container']))
        network_mode = 'container:%s' % network_mode['container']

    docker_container = state(
        Docker, 'running',
        '%s-container' % container,
        name=container,
        cap_add=cfg.get('capabilities', []),
        network_mode=network_mode,
        port_bindings=ports,
        binds=volumes,
        links=links,
        require=requires,
    )

    # Setup required networks on the host
    for net_cfg in cfg.get('networks', []):
        net_create = state(
            Cmd, 'run',
            'network-%s' % net_cfg['id'],
            name='netcfg create %s bridge' % net_cfg['id'],
            require=Sls('docker.network'),
        )

        net_attach = state(
            Cmd, 'run',
            '%s-network-%s' % (container, net_cfg['id']),
            name='netcfg attach %s %s %s' % (
                container,
                net_cfg['id'],
                " ".join(['--address %s' % ip_cfg['address'] for ip_cfg in net_cfg.get('ips', [])]),
            ),
            require=[
                Sls('docker.network'),
                net_create,
                docker_container,
            ],
        )
