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
