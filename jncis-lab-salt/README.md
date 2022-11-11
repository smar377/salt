## Virtualization & tooling

EVE-NG (Emulated Virtual Environment Next Generation) Community Edition v2.0.3-112 has been used for the needs of this lab.
It is a multi-vendor network emulation software that empowers network and security professionals with huge opportunities in the networking world ([eve-ng.net](https://www.eve-ng.net/))

## Inventory

2 x VMs
  - OS: Ubuntu 18.04.6 LTS
  - Processor: x2
  - Memory: 8192 MB

2 x Juniper VMX Series routers
  - OS: Junos 18.2R1.9
  - 1 x VM as virtual control-plane
  - 1 x VM as virtual forwarding-plane

## Salt architecture for Junos devices

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

## Salt Execution Modules and Functions

Ad hoc commands are executed from the command line
  - Target one or more minions
  - Functions are executed on the minions and the result is returned to the master
  - A module is a file containing executable code such as Python functions
  - You reference the specific function using the *module_name.function_name* notation
  - Complete list of modules: [Salt official modules list](https://docs.saltstack.com/en/latest/ref/modules/all/index.html)
  - General command syntax:
    - `salt [options] '<target>' <module>.<function> [arguments]` 
  - The default-matching that Salt utilizes is shell-style globbing around the minion ID
  - Example to ping all minions through event bus, not ICMP:
    - `salt '*' test.ping`
  
### Initialization of salt-master node

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

We also edit "/etc/salt/minion_id" and add the DNS A record of the salt-master node:

```bash
$ cat /etc/salt/minion_id 
master.edu.example.com
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

We add also "/srv/pillar/top.sls" file as per below to map "vmx-1" and "vmx-2" tags to "proxy-1" and "proxy-2" respectively:

```bash
$ cat /srv/pilar/top.sls
base:
  'vmx-1':
    - proxy-1
  'vmx-2':
    - proxy-2
```

#### Check salt-master service status

In order to check the health of the service we can leverage the following commands:
```bash
$ sudo service salt-master status
$ sudo service salt-master [start | stop | restart]
$ sudo service salt-master force-reload
```

#### Troubleshooting salt-master

```bash
$ sudo salt-call -l debug state.apply
$ sudo tail -f /var/log/salt/master
```

### Initialization of salt-minion1 node
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

Next we edit file "/etc/salt/minion", we modify the "master:" parameter adding the IPv4 of the salt-master node and we restart the salt-minion process for the change to take effect:

```bash
$ cat /etc/salt/minion | grep -v ^master
master: 10.254.0.200

$ sudo service salt-minion restart
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

#### Check salt-minion service status

In order to check the health of the service we can leverage the following commands:
```bash
$ sudo service salt-minion status
$ sudo service salt-minion [start | stop | restart]
$ sudo service salt-minin force-reload
```

#### Start one salt-proxy process per Junos device to be managed

```bash
$ sudo salt-proxy --proxyid=vmx-1 -d
$ sudo salt-proxy --proxyid=vmx-2 -d
```

#### Troubleshooting salt-minion

```bash
$ sudo salt-call -l debug state.apply
$ sudo tail -f /var/log/salt/minion
$ sudo tail -f /var/log/salt/proxy
```

## Verify that vMX routers and salt-minion proxy processes have joined the salt-master

On master node:

```bash
# List all accepted public keys from the managed devices
$ sudo salt-key -L
Accepted Keys:
minion1.edu.example.com
vmx-1
vmx-2
Denied Keys:
Unaccepted Keys:
Rejected Keys:
```

During the first time, the public keys of the managed systems will be detected from salt-master, but not accepted.
In order to accept all pending keys we need to run:

```bash
# In contrast, we can delete all keys by adding "-D" key instead of "-A"
$ sudo salt-key -A
```

## Check basic connectivity between vMX routers and salt-master

```bash
$ sudo salt vmx* test.ping
vmx-1:
    True
vmx-2:
    True
```

## Check interfaces of vMX routers

```bash
$ sudo salt vmx* junos.cli "show interfaces ge-0/0/2 terse" 
vmx-1:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        ge-0/0/2                up    up
        ge-0/0/2.32767          up    up   multiservice
    out:
        True
vmx-2:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        ge-0/0/2                up    up
        ge-0/0/2.32767          up    up   multiservice
    out:
        True
```

```bash
$ sudo salt vmx* junos.cli "show interfaces fxp0.0 terse"
vmx-2:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        fxp0.0                  up    up   inet     10.254.0.42/24  
    out:
        True
vmx-1:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        fxp0.0                  up    up   inet     10.254.0.41/24  
    out:
        True
```
