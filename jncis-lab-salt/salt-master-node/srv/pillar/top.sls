base:
  'vmx-1':
    - proxy-1
    - l3vpn/vmx-1
  'vmx-2':
    - proxy-2
    - l3vpn/vmx-2
  'vmx*':
    - infrastructure_data
    - l3vpn/customers
