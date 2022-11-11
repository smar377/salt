## Virtualization & tooling
EVE-NG (Emulated Virtual Environment Next Generation) Community Edition v2.0.3-112 has been used for the needs of this lab.
It is a multi-vendor network emulation software that empowers network and security professionals with huge opportunities in the networking world ([eve-ng.net](https://www.eve-ng.net/))

## Inventory
2 x VMs
  - OS: Ubuntu 18.04.6 LTS
  - Processor: x2
  - Memory: 8192 MB

2 x Juniper VMX Series
  - OS: Junos 18.2R1.9
  - 1 x VM as virtual control-plane
  - 1 x VM as virtual forwarding-plane

## Salt architecture init
As a reminder Salt architecture supports 3 types of setup:
  - Masterless
  - Salt agentless (also known as "salt-ssh", only requirements are SSH + Python deployed on to-be-managed system
  - Proxy minion (when salt-minion cannot be deployed, but NETCONF or REST API(s) is supported)

With that being said, and since Junos devices support NETCONF and REST API(s), the proxy minion architecture is always used.
Now, for the installation of Salt, a bootstrap script is used. Download using:

```bash 
$ curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
```

and then we deploy the software according to the architecture we have.
In our case, please continue reading below for installation of the software per node.

### salt-master
On master node we run the script as per below:

```bash
# Because -M key was provided, both master and minion processes were installed
$ sudo sh bootstrap-salt.sh -M
```

Version check:

```bash
$ salt --version
salt 3004.1
$ salt-minion --version
salt-minion 3004.1
```

In "/etc/salt/master" we add the following lines:

```bash
$ cat /etc/salt/master | grep -v '^\s*$\|^\s*\#'
engines:
  - junos_syslog:
      port: 10514
file_roots:
  base:
    - /srv/salt
```

Then, in order to define the Junos devices the salt-master will talk to we specify 2 SLS (Salt State) files as per below, under "/srv/pillar" directory:

```bash
$ cat /srv/pillar/proxy-1.sls
proxy:
  proxytype: junos
  host: 10.254.0.41
  username: brook
  password: onepiece123
  port: 830

$ cat /srv/pillar/proxy-2.sls
proxy:
  proxytype: junos
  host: 10.254.0.42
  username: brook
  password: onepiece123
  port: 830
```

```bash
$ tree /srv/
/srv/
├── pillar
│   ├── infrastructure_data.sls
│   ├── l3vpn
│   │   ├── customers.sls
│   │   ├── vmx-1.sls
│   │   └── vmx-2.sls
│   ├── proxy-1.sls
│   ├── proxy-2.sls
│   └── top.sls
└── salt
    ├── enable_syslog.set
    ├── infrastructure_config.conf
    ├── l3vpn.conf
    ├── _modules
    │   └── dayonejunos.py
    ├── myconfig.set
    ├── provision_infrastructure.sls
    └── provision_l3vpn.sls
```

### salt-minion1
On minion node we run the script as per below:

```bash
# We do not specify the -M key as we want only the minion processes to be installed
$ sudo sh bootstrap-salt.sh
```

Version check:

```bash
$ salt-minion --version
salt-minion 3004.1
```

Next we edit file "/etc/salt/minion" and we add an entry pointing to salt-master node IPv4 address:

```bash
$ cat /etc/salt/minion | grep -v '^\s*$\|^\s*\#'
master: 10.254.0.200
```

Additionally, we do the same while editing "/etc/salt/proxy" file: 

```bash
$ cat /etc/salt/proxy | grep -v '^\s*$\|^\s*\#'
master: 10.254.0.200
```

We also edit "/etc/salt/minion_id" and add the DNS A record of the salt-minion node:

```bash
$ cat /etc/salt/minion_id 
minion1.edu.example.com
```

#### Check service/process status

In order to check the health of the service we can leverage the following commands:
```bash
$ sudo service salt-minion status
$ sudo service salt-minion [start | stop | restart]
```

#### Start one salt-proxy process per Junos device we want to manage
```bash
$ sudo salt-proxy --proxyid=vmx-1 -d
$ sudo salt-proxy --proxyid=vmx-2 -d
```

#### Troubleshooting
```bash
$ sudo salt-call -l debug state.apply
$ sudo tail -f /var/log/salt/minion
$ sudo tail -f /var/log/salt/proxy
```
