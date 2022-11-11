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
### salt-master

```bash
$ cat /etc/salt/master | grep -v '^\s*$\|^\s*\#'
engines:
  - junos_syslog:
      port: 10514
file_roots:
  base:
    - /srv/salt
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

```bash
$ $ cat /etc/salt/minion | grep -v '^\s*$\|^\s*\#'
master: 10.254.0.200

$ cat /etc/salt/minion_id 
minion1.edu.example.com

$ cat /etc/salt/proxy | grep -v '^\s*$\|^\s*\#'
master: 10.254.0.200

sudo service salt-minion status
sudo service salt-minion restart
sudo salt-proxy --proxyid=vmx-1 -d
sudo salt-proxy --proxyid=vmx-2 -d
sudo salt-call -l debug state.apply
sudo tail -f /var/log/salt/minion
sudo tail -f /var/log/salt/proxy

ps aux | grep salt-proxy
```
