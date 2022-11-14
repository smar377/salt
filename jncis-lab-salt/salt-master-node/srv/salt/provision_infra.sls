Install the infrastructure services config:
  junos.install_config:
   - name: salt:///configs/infra_config.conf
   - replace: True
   - timeout: 100
   - diffs_file: /home/eve/infra_data.{{ grains.id }}.diff
