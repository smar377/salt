Install the infrastructure services config:
  junos.install_config:
   - name: salt:///configs/infra_config.conf
   - replace: True
   - timeout: 100
