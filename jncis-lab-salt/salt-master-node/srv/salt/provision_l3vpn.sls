Install L3 VPN config:
  junos.install_config:
    - name: salt:///l3vpn.conf
    - replace: True
    - timeout: 100
    - diffs_file: /home/eve/diff-{{ grains.id }}.log
