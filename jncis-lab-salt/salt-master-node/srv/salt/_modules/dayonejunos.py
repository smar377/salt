def hello(*args, **kwargs):
    ret = {}
    ret['pillar'] = __pillar__
    ret['grain'] = __grains__
    ret['rpc_result'] = __salt__['junos.rpc']('get-interface-information')
    return ret
