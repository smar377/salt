## Intro

This lab was developed while studying e-book [DAY ONE: AUTOMATING JUNOS
WITH SALT by Juniper Networks](https://www.juniper.net/documentation/en_US/day-one-books/DO_Automating_SALT.pdf)

## Virtualization & Tooling

EVE-NG (Emulated Virtual Environment Next Generation) Community Edition v2.0.3-112 has been used for the needs of this lab.
It is a multi-vendor network emulation software that empowers network and security professionals with huge opportunities in the networking world ([eve-ng.net](https://www.eve-ng.net/))

## Inventory

2 x VMs
  - OS: Ubuntu 18.04.6 LTS
  - Processor: x2
  - Memory: 4 GB
  - Interfaces:
    - **salt-master**:
      - `Ethernet (ens3): 192.168.2.109/24 -> Internet access`
      - `Ethernet (ens4): 10.254.0.200/24 -> MGT access`
    - **salt-minion1**:
      - `Ethernet (ens3): 192.168.2.108/24 -> Internet access`
      - `Ethernet (ens4): 10.254.0.51/24 -> MGT access`

2 x Juniper VMX Series routers
  - OS: Junos 18.2R1.9
  - 1 x VM as virtual control-plane
  - 1 x VM as virtual forwarding-plane
  - Interfaces:
    - **vmx-1**:
      - `fxp0.0: 10.254.0.41/24 -> MGT access`
      - `ge-0/0/0.0: 10.0.0.111/24 -> MPLS`
    - **vmx-2**:
      - `fxp0.0: 10.254.0.42/24 -> MGT access`
      - `ge-0/0/0.0: 10.0.0.222/24 -> MPLS`
   
## Junos Devices Preparation

- Create SSH keys on salt-master and salt-minion1 and copy on vMX routers:
  - On Salt machines:
    - `$ ssh-keygen -b 2048 -t rsa`
    - `$ scp /home/brook/.ssh/id_rsa.pub brook@10.254.0.41:/var/tmp`
  - On vMX routers:
    - Be sure to enable NETCONF: `# set system services netconf ssh`
    - Load the keys previously copied to `/var/tmp`: `# set system login user brook authentication load-key-file /var/tmp/id_rsa.pub`
    - Delete the keys from `/var/tmp`: `# file delete /var/tmp/id_rsa.pub`

*(Not for our scenario) Optionally if we want we can also disable authentication via SSH with password using:
`# set system services ssh no-password-authentication`*

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

## Salt Architecture for Junos

As a reminder Salt architecture supports 3 types of setup:
  - Masterless
  - Salt agentless (also known as "salt-ssh", only requirements are SSH + Python deployed on to-be-managed system
  - Proxy minion (when salt-minion cannot be deployed, but NETCONF or REST API(s) is supported)

With that being said, and since Junos devices support NETCONF, the proxy minion architecture is always used:
  - Junos proxy minions use the Junos PyEZ library to connect through NETCONF and perform various management tasks
    - NETCONF must be enabled on managed devices
    - `Junos PyEZ & jxmlease` must be installed on the server running proxy minion  
  - PyEZ facts are stored as Salt grains
  - One proxy minion instance manages one Junos device
  - Uses about 100 MB of RAM
  - Can run on any server, including the same server as master

Now, for the installation of Salt, a bootstrap script is used. Download using:

```bash 
$ curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
```

and then we deploy the software according to the architecture we have.
In our case, please continue reading below for installation of the software per node.
  
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

In `/etc/salt/master` we add the following lines:

```bash
$ cat /etc/salt/master | grep -v '^\s*$\|^\s*\#'
engines:
  - junos_syslog:
      port: 10514
file_roots:
  base:
    - /srv/salt
```

We also edit `/etc/salt/minion_id` and add the DNS A record of the salt-master node:

```bash
$ cat /etc/salt/minion_id 
master.edu.example.com
```

We add also `/srv/pillar/top.sls` file, which defines which minions have access to which Pillar data (*proxy-1 and "proxy-2"*):

```bash
$ cat /srv/pilar/top.sls
base:
  'vmx-1':
    - proxy-1
  'vmx-2':
    - proxy-2
```

Then, for above to work we need to define the various data associated with the minions. We do this by leveraging the Salt Pillar system. For the 2 vMX Junos devices we specify 2 SLS (Salt State) files as per below, under "/srv/pillar" directory:

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
  
# Last but not least we need to refresh the pillar data for any changes to take effect
$ sudo salt 'vmx-*' saltutil.refresh_pillar
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

Steps to be followed:

1. Tell the proxy minion where the master is
2. Start proxy minions
3. Accept the keys (on `salt-master` in our case)

On minion node we run the script as per below:

```bash
# We do **NOT** specify the -M key as we want only the minion processes to be installed
$ sudo sh bootstrap-salt.sh
```

Version check:

```bash
$ salt-minion --version
salt-minion 3004.1
```

Next we edit files `/etc/salt/minion` and `/etc/salt/proxy`, we modify the `master:` parameter adding the IPv4 of the salt-master node and we restart the salt-minion process for the changes to take effect:

```bash
$ cat /etc/salt/proxy | grep -v ^master
master: 10.254.0.200

$ cat /etc/salt/minion | grep -v ^master
master: 10.254.0.200

$ sudo service salt-minion restart
```

We also edit `/etc/salt/minion_id` and add the DNS A record of the salt-minion node:

```bash
$ cat /etc/salt/minion_id 
minion1.edu.example.com
```

Start one salt-proxy process per Junos device to be managed:

```bash
$ sudo salt-proxy --proxyid=vmx-1 -d
$ sudo salt-proxy --proxyid=vmx-2 -d
```

And last but not least, do *NOT* forget that we need to check the keys and accept them on `salt-master` node:

#### Check salt-minion service status

In order to check the health of the service we can leverage the following commands:
```bash
$ sudo service salt-minion status
$ sudo service salt-minion [start | stop | restart]
$ sudo service salt-minin force-reload
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

## Check connectivity between vMX routers and salt-master

```bash
$ sudo salt vmx* test.ping
vmx-1:
    True
vmx-2:
    True
```

## Check vMX interfaces

```bash
$ sudo salt vmx* junos.cli "show interfaces terse ge-0/0/0"
vmx-1:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        ge-0/0/0                up    up
        ge-0/0/0.0              up    up   inet     10.0.0.111/24   
                                           mpls    
                                           multiservice
    out:
        True
vmx-2:
    ----------
    message:
        
        Interface               Admin Link Proto    Local                 Remote
        ge-0/0/0                up    up
        ge-0/0/0.0              up    up   inet     10.0.0.222/24   
                                           mpls    
                                           multiservice
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

## Other useful Salt commands leveraging various Junos PyEZ modules

```bash
$ sudo salt vmx* junos.rpc get-interface-information interface-name=ge-0/0/0 terse=True --out=json
$ sudo salt vmx* junos.ping "10.254.0.1" count=2
$ sudo salt vmx* junos.facts
$ sudo salt vmx* junos.lock
$ sudo salt vmx* junos.load 'salt://myconfig.set' replace='True'
$ sudo salt vmx* junos.diff
$ sudo salt vmx* junos.commit
$ sudo salt vmx* junos.commit_check
$ sudo salt vmx* junos.unlock
$ sudo salt vmx* junos.install_config 'salt://myconfig.set'
$ sudo salt vmx* junos.file_copy /home/eve/hello.slax /var/db/scripts/op
$ sudo salt vmx* junos.install_os salt:///junos-openconfig-x86-32-0.0.0.9.tgz
```

## Case Study #1

- Configure DNS, NTP server parameters and two testing physical interface on two vMX devices:
  - DNS servers: 192.168.0.253, 192.168.0.254
  - NTP servers: 192.168.0.250, 192.168.0.251
  - Interfaces: 
    - On **vmx-1**: `ge-0/0/8` and `ge-0/0/9` with 10.0.8.111/24 and 10.0.9.111/24
    - On **vmx-2**: `ge-0/0/8` and `ge-0/0/9` with 10.0.8.222/24 and 10.0.9.222/24  

- Steps to be going through:

### 1. Define pillar data

```bash
$ cat /srv/pillar/infra_data.sls 
ntp_servers:
 - 192.168.0.250
 - 192.168.0.251
dns_servers:
 - 192.168.0.253
 - 192.168.0.254
```

```bash
$ cat /srv/pillar/interfaces-vmx1.sls 
interfaces:
 - name: ge-0/0/8
   unit: 0
   address: 10.0.8.111/24
 - name: ge-0/0/9
   unit: 0
   address: 10.0.9.111/24
```

```bash
$ cat /srv/pillar/interfaces-vmx2.sls 
interfaces:
 - name: ge-0/0/8
   unit: 0
   address: 10.0.8.222/24
 - name: ge-0/0/9
   unit: 0
   address: 10.0.9.222/24
```

### 2. Update pillar top file and refresh

```
$ cat /srv/pillar/top.sls 
base:
  'vmx-1':
    - proxy-1
    - interfaces-vmx1
  'vmx-2':
    - proxy-2
    - interfaces-vmx2
  'vmx*':
    - infra_data
```

```bash
$ sudo salt 'vmx*' saltutil.refresh_pillar
vmx-1:
    True
vmx-2:
    True
```

### 3. Define template configuration

```jinja
$ cat /srv/salt/configs/infra_config.conf 
system {
  replace: name-server {
{%- for dns_server in pillar.dns_servers %}
  {{ dns_server }};
{%- endfor %}
  }
  replace: ntp {
{%- for ntp_server in pillar.ntp_servers %}
    server {{ ntp_server }};
{%- endfor %}
  }
}
```

```jinja
$ cat /srv/salt/configs/interfaces.conf 
interfaces {
{%- for iface in pillar.interfaces %}
    {{ iface.name }} {
        unit {{ iface.unit }} {
            family inet {
                address {{ iface.address }};
            }
        }
    }
{%- endfor %}
}
```

### 4. Define state SLS files

```bash
$ cat /srv/salt/provision_infra.sls 
Install the infrastructure services config:
  junos.install_config:
   - name: salt:///configs/infra_config.conf
   - diffs_file: /home/eve/infra_data.{{grains.id}}.diff
   - replace: True
   - timeout: 100
```

```bash
$ cat /srv/salt/provision_interfaces.sls 
Provision interface configs:
  junos.install_config:
   - name: salt:///configs/interfaces.conf
   - diffs_file: /home/eve/interfaces-{{grains.id}}.diff
```

### 5. Apply the state

```bash
$ sudo salt 'vmx*'' state.apply provision_infra
vmx-2:
----------
          ID: Install the infrastructure services config
    Function: junos.install_config
        Name: salt:///configs/infra_config.conf
      Result: True
     Comment: 
     Started: 10:49:37.037028
    Duration: 1528.968 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-2
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   1.529 s
vmx-1:
----------
          ID: Install the infrastructure services config
    Function: junos.install_config
        Name: salt:///configs/infra_config.conf
      Result: True
     Comment: 
     Started: 10:49:37.059113
    Duration: 1510.228 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-1
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   1.510 s
```

```bash
$ sudo salt vmx* state.apply provision_interfaces
vmx-1:
----------
          ID: Provision interface configs
    Function: junos.install_config
        Name: salt:///configs/interfaces.conf
      Result: True
     Comment: 
     Started: 11:12:59.672869
    Duration: 2143.031 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-1
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   2.143 s
vmx-2:
----------
          ID: Provision interface configs
    Function: junos.install_config
        Name: salt:///configs/interfaces.conf
      Result: True
     Comment: 
     Started: 11:12:59.691501
    Duration: 2168.813 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-2
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   2.169 s
```

*Important:* In case we try to apply the same state again we will see that Salt detects that **NO** change on the devices is needed, and does **NOT** perform a commit. Salt will try to configure the state again, only when a change has happened on the data given:

```bash
$ sudo salt vmx* state.apply provision_interfaces
vmx-2:
----------
          ID: Provision interface configs
    Function: junos.install_config
        Name: salt:///configs/interfaces.conf
      Result: True
     Comment: 
     Started: 11:25:45.030674
    Duration: 394.726 ms
     Changes:   
              ----------
              message:
                  Configuration already applied!
              out:
                  True

Summary for vmx-2
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time: 394.726 ms
vmx-1:
----------
          ID: Provision interface configs
    Function: junos.install_config
        Name: salt:///configs/interfaces.conf
      Result: True
     Comment: 
     Started: 11:25:45.087260
    Duration: 449.76 ms
     Changes:   
              ----------
              message:
                  Configuration already applied!
              out:
                  True

Summary for vmx-1
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time: 449.760 ms
```

### 6. Check on the devices

```bash
$ sudo salt vmx* junos.cli "show configuration | compare rollback 1"
vmx-2:
    ----------
    message:
        
        [edit system]
        +  name-server {
        +      192.168.0.253;
        +      192.168.0.254;
        +  }
        [edit system ntp]
        +    server 192.168.0.250;
        +    server 192.168.0.251;
    out:
        True
vmx-1:
    ----------
    message:
        
        [edit system]
        +  name-server {
        +      192.168.0.253;
        +      192.168.0.254;
        +  }
        [edit system ntp]
        +    server 192.168.0.250;
        +    server 192.168.0.251;
    out:
        True
```

```bash
# On salt-minion1 VM we check the .diff files
$ cat infra_data.vmx-1.diff 

[edit system]
+  name-server {
+      192.168.0.253;
+      192.168.0.254;
+  }
[edit system ntp]
+    server 192.168.0.250;
+    server 192.168.0.251;

$ cat infra_data.vmx-2.diff 

[edit system]
+  name-server {
+      192.168.0.253;
+      192.168.0.254;
+  }
[edit system ntp]
+    server 192.168.0.250;
+    server 192.168.0.251;
```

```bash
# Check from salt-master VM utilizing the junos.cli module
$ sudo salt vmx* junos.cli "show configuration | compare rollback 1"
vmx-2:
    ----------
    message:
        
        [edit interfaces]
        +   ge-0/0/8 {
        +       unit 0 {
        +           family inet {
        +               address 10.0.8.222/24;
        +           }
        +       }
        +   }
        +   ge-0/0/9 {
        +       unit 0 {
        +           family inet {
        +               address 10.0.9.222/24;
        +           }
        +       }
        +   }
    out:
        True
vmx-1:
    ----------
    message:
        
        [edit interfaces]
        +   ge-0/0/8 {
        +       unit 0 {
        +           family inet {
        +               address 10.0.8.111/24;
        +           }
        +       }
        +   }
        +   ge-0/0/9 {
        +       unit 0 {
        +           family inet {
        +               address 10.0.9.111/24;
        +           }
        +       }
        +   }
    out:
        True
```

```bash
# On salt-minion1 VM we check the .diff files
$ cat interfaces-vmx-1.diff 

[edit interfaces]
+   ge-0/0/8 {
+       unit 0 {
+           family inet {
+               address 10.0.8.111/24;
+           }
+       }
+   }
+   ge-0/0/9 {
+       unit 0 {
+           family inet {
+               address 10.0.9.111/24;
+           }
+       }
+   }

$ cat interfaces-vmx-2.diff 

[edit interfaces]
+   ge-0/0/8 {
+       unit 0 {
+           family inet {
+               address 10.0.8.222/24;
+           }
+       }
+   }
+   ge-0/0/9 {
+       unit 0 {
+           family inet {
+               address 10.0.9.222/24;
+           }
+       }
+   }
```

## Case Study #2

We assume there is a set of provider edge (PE) routers and each PE router generally has multiple connected L3VPN customers. The goal is to provision the corresponding configuration automatically using Salt. The example topology used is depicted in `topology.md` file.

There is two vMX devices acting, this time, as MPLS PE routers. The Salt master server, as well as minion1 server running the two Junos proxy minions, are not shown. Consult previous chapters for details on how to set up Salt for managing Junos
devices.

In this example, the IP/MPLS backbone is contained of `ge-0/0/0` and `ge-0/0/1` links connecting vMX-1 and vMX-2 back-to-back. It is pre-configured and not managed by Salt.

More specifically, the initial configuration on PE vMX devices includes:

- Full configuration of core-facing interfaces (family inet and MPLS);
- Standard OSPF, LDP, and IBGP (with family inet-vpn unicast) configuration for the IP/MPLS backbone;
- Only physical parameters for customer-facing interfaces (ge-0/0/2) are configured ??? namely, flexible-vlan-tagging and encapsulation flexible-ethernet-services are configured. No units are configured on these interfaces ??? Salt must do that;
- No VRF (L3VPN) instances are configured for the customers ??? again, Salt must do that;
- The route-distinguisher-id is configured in routing-options hierarchy on both PEs, so manual configuration for route-distinguisher in VRFs is not needed.

Edge customer-facing logical interfaces and L3VPN VRF instances must be provisioned automatically using Salt, according to the Jinja templates and data specified in pillar YAML files.

As part of the solution, the following must be created or updated in Salt:
- A Jinja configuration template.
- Pillar YAML files with variable parameters, describing customers connected to each of the PE devices.
- A pillar top file to properly map pillar data to proxy minions.
- A State SLS file to provision configurations.

### 1. Define pillar data

```bash
$ tree /srv/pillar/l3vpn/
/srv/pillar/l3vpn/
????????? customers.sls
????????? vmx-1.sls
????????? vmx-2.sls

0 directories, 3 files
```

```bash
$ cat /srv/pillar/l3vpn/customers.sls 
---
customers:
  Cust_A:
    vrf_target: "target:65000:1"
    AS: 65100
  Cust_B:
    vrf_target: "target:65000:2"
    AS: 65200
```

```bash
$ cat /srv/pillar/l3vpn/vmx-1.sls 
L3VPN_data:
  - customer_id: Cust_A
    interface_name: ge-0/0/2
    unit: 100
    vlan_id: 100
    ip_mask: 10.100.0.1/24
    customer_ip: 10.100.0.2
    prefix_limit: 10
  - customer_id: Cust_B
    interface_name: ge-0/0/2
    unit: 200
    vlan_id: 200
    ip_mask: 10.200.0.1/24
    customer_ip: 10.200.0.2
    prefix_limit: 15
```

```bash
$ cat /srv/pillar/l3vpn/vmx-2.sls 
L3VPN_data:
  - customer_id: Cust_A
    interface_name: ge-0/0/2
    unit: 150
    vlan_id: 150
    ip_mask: 10.150.0.1/24
    customer_ip: 10.150.0.2
    prefix_limit: 10
  - customer_id: Cust_B
    interface_name: ge-0/0/2
    unit: 250
    vlan_id: 250
    ip_mask: 10.250.0.1/24
    customer_ip: 10.250.0.2
    prefix_limit: 15
```

### 2. Update pillar top file and refresh

```bash
$ cat /srv/pillar/top.sls 
base:
  'vmx-1':
    - proxy-1
    - interfaces-vmx1
    - l3vpn/vmx-1
  'vmx-2':
    - proxy-2
    - interfaces-vmx2
    - l3vpn/vmx-2
  'vmx*':
    - infra_data
    - l3vpn/customers
```

```bash
$ sudo salt vmx* saltutil.refresh_pillar
vmx-2:
    True
vmx-1:
    True
```

### 3. Define template configuration

```jinja
$ cat /srv/salt/configs/l3vpn.conf 
groups {
    replace:
    L3VPN-SALT {
        {% if pillar.L3VPN_data %}
        interfaces {
        {% for VPN_entry in pillar.L3VPN_data %}
            {{ VPN_entry.interface_name }} {
                unit {{ VPN_entry.unit }} {
                    vlan-id {{ VPN_entry.vlan_id }};
                    family inet {
                        address {{ VPN_entry.ip_mask }};
                    }
                }
            }
        {% endfor %}
        }
        routing-instances {
        {% for VPN_entry in pillar.L3VPN_data %}
            {{ VPN_entry.customer_id }} {
                instance-type vrf;
                vrf-table-label;
                interface {{ VPN_entry.interface_name }}.{{ VPN_entry.unit }};
                vrf-target {{ pillar.customers[VPN_entry.customer_id].vrf_target }};
                protocols {
                    bgp {
                        group EBGP-{{ VPN_entry.customer_id }} {
                            family inet {
                                unicast {
                                    prefix-limit {
                                        maximum {{ VPN_entry.prefix_limit }};
                                        teardown;
                                    }
                                }
                            }
                            peer-as {{ pillar.customers[VPN_entry.customer_id].AS }};
                            as-override;
                            neighbor {{ VPN_entry.customer_ip }};
                        }
                    }
                }
            }
        {% endfor %}
        }
        {% endif %}
    }
}
apply-groups L3VPN-SALT;
```

### 4. Define state SLS files

```bash
$ cat /srv/salt/provision_l3vpn.sls 
Install L3 VPN config:
  junos.install_config:
    - name: salt:///configs/l3vpn.conf
    - replace: True
    - timeout: 100
    - diffs_file: /home/eve/l3vpn-{{ grains.id }}.diff
```

### 5. Apply the state

```bash
$ sudo salt vmx* state.apply provision_l3vpn
vmx-2:
----------
          ID: Install L3 VPN config
    Function: junos.install_config
        Name: salt:///configs/l3vpn.conf
      Result: True
     Comment: 
     Started: 12:43:47.091335
    Duration: 1174.689 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-2
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   1.175 s
vmx-1:
----------
          ID: Install L3 VPN config
    Function: junos.install_config
        Name: salt:///configs/l3vpn.conf
      Result: True
     Comment: 
     Started: 12:43:47.061813
    Duration: 1257.784 ms
     Changes:   
              ----------
              message:
                  Successfully loaded and committed!
              out:
                  True

Summary for vmx-1
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time:   1.258 s
```

### 6. Check on the devices

```bash
# Check from salt-master VM utilizing the junos.cli module
$ sudo salt vmx* junos.cli "show configuration | compare rollback 1"
vmx-2:
    ----------
    message:
        
        [edit]
        + groups {
        +     L3VPN-SALT {
        +         interfaces {
        +             ge-0/0/2 {
        +                 unit 150 {
        +                     vlan-id 150;
        +                     family inet {
        +                         address 10.150.0.1/24;
        +                     }
        +                 }
        +                 unit 250 {
        +                     vlan-id 250;
        +                     family inet {
        +                         address 10.250.0.1/24;
        +                     }
        +                 }
        +             }
        +         }
        +         routing-instances {
        +             Cust_A {
        +                 instance-type vrf;
        +                 interface ge-0/0/2.150;
        +                 vrf-target target:65000:1;
        +                 vrf-table-label;
        +                 protocols {
        +                     bgp {
        +                         group EBGP-Cust_A {
        +                             family inet {
        +                                 unicast {
        +                                     prefix-limit {
        +                                         maximum 10;
        +                                         teardown;
        +                                     }
        +                                 }
        +                             }
        +                             peer-as 65100;
        +                             as-override;
        +                             neighbor 10.150.0.2;
        +                         }
        +                     }
        +                 }
        +             }
        +             Cust_B {
        +                 instance-type vrf;
        +                 interface ge-0/0/2.250;
        +                 vrf-target target:65000:2;
        +                 vrf-table-label;
        +                 protocols {
        +                     bgp {
        +                         group EBGP-Cust_B {
        +                             family inet {
        +                                 unicast {
        +                                     prefix-limit {
        +                                         maximum 15;
        +                                         teardown;
        +                                     }
        +                                 }
        +                             }
        +                             peer-as 65200;
        +                             as-override;
        +                             neighbor 10.250.0.2;
        +                         }
        +                     }
        +                 }
        +             }
        +         }
        +     }
        + }
        + apply-groups L3VPN-SALT;
    out:
        True
vmx-1:
    ----------
    message:
        
        [edit]
        + groups {
        +     L3VPN-SALT {
        +         interfaces {
        +             ge-0/0/2 {
        +                 unit 100 {
        +                     vlan-id 100;
        +                     family inet {
        +                         address 10.100.0.1/24;
        +                     }
        +                 }
        +                 unit 200 {
        +                     vlan-id 200;
        +                     family inet {
        +                         address 10.200.0.1/24;
        +                     }
        +                 }
        +             }
        +         }
        +         routing-instances {
        +             Cust_A {
        +                 instance-type vrf;
        +                 interface ge-0/0/2.100;
        +                 vrf-target target:65000:1;
        +                 vrf-table-label;
        +                 protocols {
        +                     bgp {
        +                         group EBGP-Cust_A {
        +                             family inet {
        +                                 unicast {
        +                                     prefix-limit {
        +                                         maximum 10;
        +                                         teardown;
        +                                     }
        +                                 }
        +                             }
        +                             peer-as 65100;
        +                             as-override;
        +                             neighbor 10.100.0.2;
        +                         }
        +                     }
        +                 }
        +             }
        +             Cust_B {
        +                 instance-type vrf;
        +                 interface ge-0/0/2.200;
        +                 vrf-target target:65000:2;
        +                 vrf-table-label;
        +                 protocols {
        +                     bgp {
        +                         group EBGP-Cust_B {
        +                             family inet {
        +                                 unicast {
        +                                     prefix-limit {
        +                                         maximum 15;
        +                                         teardown;
        +                                     }
        +                                 }
        +                             }
        +                             peer-as 65200;
        +                             as-override;
        +                             neighbor 10.200.0.2;
        +                         }
        +                     }
        +                 }
        +             }
        +         }
        +     }
        + }
        + apply-groups L3VPN-SALT;
    out:
        True
```

```bash
# On salt-minion1 check .diff files
$ cat /home/eve/l3vpn-vmx-1.diff

[edit]
+ groups {
+     L3VPN-SALT {
+         interfaces {
+             ge-0/0/2 {
+                 unit 100 {
+                     vlan-id 100;
+                     family inet {
+                         address 10.100.0.1/24;
+                     }
+                 }
+                 unit 200 {
+                     vlan-id 200;
+                     family inet {
+                         address 10.200.0.1/24;
+                     }
+                 }
+             }
+         }
+         routing-instances {
+             Cust_A {
+                 instance-type vrf;
+                 interface ge-0/0/2.100;
+                 vrf-target target:65000:1;
+                 vrf-table-label;
+                 protocols {
+                     bgp {
+                         group EBGP-Cust_A {
+                             family inet {
+                                 unicast {
+                                     prefix-limit {
+                                         maximum 10;
+                                         teardown;
+                                     }
+                                 }
+                             }
+                             peer-as 65100;
+                             as-override;
+                             neighbor 10.100.0.2;
+                         }
+                     }
+                 }
+             }
+             Cust_B {
+                 instance-type vrf;
+                 interface ge-0/0/2.200;
+                 vrf-target target:65000:2;
+                 vrf-table-label;
+                 protocols {
+                     bgp {
+                         group EBGP-Cust_B {
+                             family inet {
+                                 unicast {
+                                     prefix-limit {
+                                         maximum 15;
+                                         teardown;
+                                     }
+                                 }
+                             }
+                             peer-as 65200;
+                             as-override;
+                             neighbor 10.200.0.2;
+                         }
+                     }
+                 }
+             }
+         }
+     }
+ }
+ apply-groups L3VPN-SALT;
```

```bash
$ cat /home/eve/l3vpn-vmx-2.diff

[edit]
+ groups {
+     L3VPN-SALT {
+         interfaces {
+             ge-0/0/2 {
+                 unit 150 {
+                     vlan-id 150;
+                     family inet {
+                         address 10.150.0.1/24;
+                     }
+                 }
+                 unit 250 {
+                     vlan-id 250;
+                     family inet {
+                         address 10.250.0.1/24;
+                     }
+                 }
+             }
+         }
+         routing-instances {
+             Cust_A {
+                 instance-type vrf;
+                 interface ge-0/0/2.150;
+                 vrf-target target:65000:1;
+                 vrf-table-label;
+                 protocols {
+                     bgp {
+                         group EBGP-Cust_A {
+                             family inet {
+                                 unicast {
+                                     prefix-limit {
+                                         maximum 10;
+                                         teardown;
+                                     }
+                                 }
+                             }
+                             peer-as 65100;
+                             as-override;
+                             neighbor 10.150.0.2;
+                         }
+                     }
+                 }
+             }
+             Cust_B {
+                 instance-type vrf;
+                 interface ge-0/0/2.250;
+                 vrf-target target:65000:2;
+                 vrf-table-label;
+                 protocols {
+                     bgp {
+                         group EBGP-Cust_B {
+                             family inet {
+                                 unicast {
+                                     prefix-limit {
+                                         maximum 15;
+                                         teardown;
+                                     }
+                                 }
+                             }
+                             peer-as 65200;
+                             as-override;
+                             neighbor 10.250.0.2;
+                         }
+                     }
+                 }
+             }
+         }
+     }
+ }
+ apply-groups L3VPN-SALT;
```


*Important:* In case we try to apply the same state again we will see that Salt detects that **NO** change on the devices is needed, and does **NOT** perform a commit. Salt will try to configure the state again, only when a change has happened on the data given:

```bash
$ sudo salt vmx* state.apply provision_l3vpn
[sudo] password for eve: 
vmx-2:
----------
          ID: Install L3 VPN config
    Function: junos.install_config
        Name: salt:///configs/l3vpn.conf
      Result: True
     Comment: 
     Started: 13:53:55.209873
    Duration: 470.971 ms
     Changes:   
              ----------
              message:
                  Configuration already applied!
              out:
                  True

Summary for vmx-2
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time: 470.971 ms
vmx-1:
----------
          ID: Install L3 VPN config
    Function: junos.install_config
        Name: salt:///configs/l3vpn.conf
      Result: True
     Comment: 
     Started: 13:53:55.261932
    Duration: 422.995 ms
     Changes:   
              ----------
              message:
                  Configuration already applied!
              out:
                  True

Summary for vmx-1
------------
Succeeded: 1 (changed=1)
Failed:    0
------------
Total states run:     1
Total run time: 422.995 ms
```

### Test routing table and connectivity

```bash
brook@vmx-1> show route table Cust_A.inet.0

Cust_A.inet.0: 3 destinations, 3 routes (3 active, 0 holddown, 0 hidden)
+ = Active Route, - = Last Active, * = Both

10.100.0.0/24 		*[Direct/0] 00:06:50
 									 > via ge-0/0/2.100
10.100.0.1/32 		*[Local/0] 00:06:50
 										 Local via ge-0/0/2.100
10.150.0.0/24 		*[BGP/170] 00:06:50, localpref 100, from 192.168.0.2
 									   AS path: I, validation-state: unverified
 										 to 10.0.0.222 via ge-0/0/0.0, Push 16
 									 > to 10.0.1.222 via ge-0/0/1.0, Push 16
```

The route to the remote network is there. You can also check to see if a ping between remote Customer-A instances works as it should. The VR-A here is a virtual router instance created manually on the vmx-1 just for testing purposes (emulating the Customer-A's CE device):

```bash
brook@vmx-1> ping 10.150.0.2 routing-instance VR-A source 10.100.0.2 rapid
PING 10.150.0.2 (10.150.0.2): 56 data bytes
!!!!!
--- 10.150.0.2 ping statistics ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max/stddev = 2.156/2.371/2.679/0.173 ms
```
