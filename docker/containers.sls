#!pyobjects

import os
import urllib2

from salt.utils import pyobjects

Sls = pyobjects.StateFactory('sls')
Docker = pyobjects.StateFactory('dockerng')
Iptables = pyobjects.StateFactory('iptables')
Kmod = pyobjects.StateFactory('kmod')

def state(_cls, _func, _id, **kwargs):
    from salt.utils import pyobjects

    try:
        return getattr(_cls, _func)(_id, **kwargs).requisite
    except pyobjects.DuplicateState:
        return _cls(_id)

def resolve(value):
    if isinstance(value, dict):
        if 'type' in value:
            if value['type'] == 'pillar':
                return pillar(value['key'])
            elif value['type'] == 'request':
                request = urllib2.urlopen(value['url'])
                return response.read()

        raise Error("Invalid value: %s" % value)

    return value

# Setup chain for managing docker binds
firewall_binds_chain = state(
    Iptables, 'chain_present',
    'docker-containers-firewall-binds',
    name='TOZD_DOCKER_BINDS',
    table='mangle',
    require=Pkg('iptables'),
)

firewall_binds_chain = state(
    Iptables, 'flush',
    'docker-containers-firewall-binds-flush',
    chain='TOZD_DOCKER_BINDS',
    table='mangle',
    require=firewall_binds_chain,
)

firewall_binds_chain = state(
    Iptables, 'insert',
    'docker-containers-firewall-binds-attach',
    table='mangle',
    chain='PREROUTING',
    position=1,
    jump='TOZD_DOCKER_BINDS',
    require=firewall_binds_chain,
)

# Setup ACCEPT/DROP rules in filter FORWARD table based on marks
DOCKER_MARK_ACCEPT = 81000
DOCKER_MARK_DROP = 81001

firewall = state(
    Iptables, 'insert',
    'docker-containers-firewall-mark-accept',
    table='filter',
    chain='FORWARD',
    position=1,
    match='mark',
    mark=DOCKER_MARK_ACCEPT,
    jump='ACCEPT',
    require=Pkg('iptables'),
)

firewall = state(
    Iptables, 'insert',
    'docker-containers-firewall-mark-drop',
    table='filter',
    chain='FORWARD',
    position=1,
    match='mark',
    mark=DOCKER_MARK_DROP,
    jump='DROP',
    require=firewall,
)

# Automatically configure docker-hosts on all containers when detected
docker_hosts = None
for container, cfg in pillar('docker:containers', {}).items():
    if cfg.get('image', '') != 'tozd/docker-hosts':
        continue

    # Find the volume bound under /hosts
    for vol_name, vol_cfg in cfg.get('volumes', {}).iteritems():
        if vol_cfg.get('bind', '') == '/hosts':
            docker_hosts = (container, vol_name)
            break

# Setup docker containers
for container, cfg in pillar('docker:containers', {}).items():
    cfg.setdefault('volumes', {})

    docker_image = state(
        Docker, 'image_present',
        '%s-image' % container,
        name="%s:%s" % (cfg['image'], cfg.get('tag', 'latest')),
        # Pull image even if already present.
        force=True,
        require=Sls('docker.base'),
    )

    requires = [docker_image]
    binds = []

    # Automatically add the docker-hosts volume when detected
    if docker_hosts is not None:
        dh_container, dh_volume = docker_hosts

        if container != dh_container:
            cfg['volumes'][dh_volume] = {
                'bind': '/etc/hosts',
                'type': 'container',
                'container': dh_container,
                'readonly': True,
            }

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
            binds.append("%s:%s:ro" % (cfg_host_path, cfg_path))
            requires.append(volume)

    # Create the required files
    for file_path, contents in cfg.get('files', {}).items():
        requires.append(state(
            File, 'managed',
            file_path,
            contents=contents,
            user='root',
            group='root',
            mode=644,
            makedirs=True,
        ))

    # Automatically add required volumes for systemd inside container
    if cfg.get('image', '') in ['tozd/ubuntu-systemd', 'tozd/ubuntu-user']:
        cfg['volumes']['/srv/tmp/systemd-cgroup'] = {
            'bind': '/sys/fs/cgroup',
            'readonly': True,
        }
        cfg['volumes']['/srv/tmp/%s/run' % container] = {
            'bind': '/run',
            'type': 'tmpfs',
        }
        cfg['volumes']['/srv/tmp/%s/run-lock' % container] = {
            'bind': '/run/lock',
            'type': 'tmpfs',
        }

    # Create the required volumes
    for vol_name, vol_cfg in cfg['volumes'].items():
        if vol_cfg.get('readonly', False):
            read_flag = 'ro'
        else:
            read_flag = 'rw'
        binds.append("%s:%s:%s" % (vol_name, vol_cfg['bind'], read_flag))

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
        elif vol_type == 'tmpfs':
            volume = state(
                Mount, 'mounted',
                vol_name,
                device='tmpfs',
                fstype=vol_type,
                opts=vol_cfg.get('opts', 'nodev,nosuid,mode=755,size=65536k'),
                user=vol_cfg.get('user', 'root'),
                mkmnt=True,
                persist=True,
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
    links = []
    for link_name, link_alias in cfg.get('links', {}).items():
        requires.append(Docker('%s-container' % link_name))
        links.append("%s:%s" % (link_name, link_alias))

    # Setup required ports
    port_bindings = []
    for port_def, port_bind in cfg.get('ports', {}).items():
        port_bind['ip'] = resolve(port_bind['ip'])

        port_bindings.append("%s:%s:%s" % (port_bind['ip'], port_bind['port'], port_def))

        # Default policy for this ip/port is DROP
        firewall = state(
            Iptables, 'append',
            '%s-container-port-dn-drop-%s-%s' % (container, port_bind['ip'], port_bind['port']),
            **{
                'table': 'mangle',
                'chain': 'TOZD_DOCKER_BINDS',
                'jump': 'MARK',
                'set-mark': DOCKER_MARK_DROP,
                'destination': '%s/32' % port_bind['ip'],
                'dport': port_bind['port'],
                'proto': 'tcp' if 'tcp' in port_def else 'udp',
                'save': True,
                'require': Pkg('iptables'),
            }
        )
        requires.append(firewall)

        # Setup firewall rules
        sources = port_bind.get('firewall', {}).get('source', ['0.0.0.0/0'])
        for source in sources:
            firewall = state(
                Iptables, 'append',
                '%s-container-port-dp-%s-%s-%s' % (container, port_bind['ip'], port_bind['port'], source),
                table='filter',
                chain='INPUT',
                jump='ACCEPT',
                source=source,
                destination='%s/32' % port_bind['ip'],
                dport=port_bind['port'],
                proto='tcp' if 'tcp' in port_def else 'udp',
                save=True,
                require=Pkg('iptables'),
            )
            requires.append(firewall)

            # Mark incoming packets to support Docker NAT (without docker-proxy)
            firewall = state(
                Iptables, 'append',
                '%s-container-port-dn-%s-%s-%s' % (container, port_bind['ip'], port_bind['port'], source),
                **{
                    'table': 'mangle',
                    'chain': 'TOZD_DOCKER_BINDS',
                    'jump': 'MARK',
                    'set-mark': DOCKER_MARK_ACCEPT,
                    'source': source,
                    'destination': '%s/32' % port_bind['ip'],
                    'dport': port_bind['port'],
                    'proto': 'tcp' if 'tcp' in port_def else 'udp',
                    'save': True,
                    'require': Pkg('iptables'),
                }
            )
            requires.append(firewall)

    # Prepare the environment
    cfg_environment = cfg.get('environment', {})
    environment = {}
    if isinstance(cfg_environment, dict):
        # Direct environment variable specification
        environment.update(cfg_environment)
    elif isinstance(cfg_environment, list):
        for item in cfg_environment:
            if isinstance(item, dict):
                # Direct environment variable specification
                environment.update(item)
            elif isinstance(item, basestring):
                # Reference to common environment
                item = pillar('docker:environments:%s' % item)
                environment.update(item)

    # Assure that all values are strings.
    for key, value in environment.items():
      environment[key] = str(resolve(value))

    # Configure resource limits
    resources = cfg.get('resources', {})

    network_mode = cfg.get('network_mode', None)
    if network_mode is not None:
        if network_mode.get('type', None) == 'container':
            requires.append(Docker('%s-container' % network_mode['container']))
            network_mode = 'container:%s' % network_mode['container']
        else:
            # TODO: Support attaching to multiple networks.
            # TODO: Is there a better way to require a network's state without recreating it every time?
            docker_network = state(
                Docker, 'network_present',
                '%s-network' % network_mode['name'],
                name=network_mode['name'],
                driver=network_mode.get('driver', None),
                require=Sls('docker.base'),
            )
            requires.append(docker_network)
            network_mode = network_mode['name']
    else:
        network_mode = 'bridge'

    capabilities_add = []
    capabilities_drop = []
    for capability in cfg.get('capabilities', []):
        if isinstance(capability, dict):
            if capability.get('drop', False):
                capabilities_drop.append(capability['name'])
            else:
                capabilities_add.append(capability['name'])
        else:
            capabilities_add.append(capability)

    docker_container = state(
        Docker, 'running',
        '%s-container' % container,
        name=container,
        hostname=container,
        image='%s:%s' % (cfg['image'], cfg.get('tag', 'latest')),
        environment=environment,
        port_bindings=port_bindings,
        memory=resources.get('memory', 0),
        cap_add=capabilities_add,
        cap_drop=capabilities_drop,
        privileged=cfg.get('privileged', False),
        network_mode=network_mode,
        binds=binds,
        links=links,
        restart_policy='unless-stopped',
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
