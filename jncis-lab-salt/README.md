# salt-master
```
$ cat /etc/salt/master | grep -v '^\s*$\|^\s*\#'
engines:
  - junos_syslog:
      port: 10514
file_roots:
  base:
    - /srv/salt
```

```
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

# salt-minion1
