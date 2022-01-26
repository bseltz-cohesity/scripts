#!/usr/bin/env python
"""get cluster vips by least busy CPU"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-l', '--vlanid', type=int, default=0)
parser.add_argument('-n', '--nodecount', type=int, default=4)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
vlanid = args.vlanid
nodecount = args.nodecount

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True, quiet=True)

context = getContext()

nowMsecs = int(timeAgo(1, 'seconds') / 1000)
hourAgoMsecs = int(timeAgo(1, 'hours') / 1000)

vlans = [v for v in api('get', 'vlans?_includeTenantInfo=true') if v['id'] == vlanid]
if vlans is not None and len(vlans) > 0:
    vlan = vlans[0]
else:
    exit(1)

vips = vlan['ips']
nodes = []

for v in vips:
    context['APIROOT'] = 'https://%s/irisservices/api/v1' % v
    setContext(context)
    nodeinfo = api('get', 'node/status')
    nodeid = nodeinfo['id']
    cpustats = api('get', 'statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kCpuUsagePct&metricUnitType=9&range=day&rollupFunction=average&rollupIntervalSecs=360&schemaName=kSentryNodeStats&startTimeMsecs=%s' % (nowMsecs, nodeid, hourAgoMsecs))
    cpustat = cpustats['dataPointVec'][-1]['data']['doubleValue']
    nodes.append({'nodeId': nodeid, 'vip': v, 'cpustat': cpustat})

x = 0
for node in sorted(nodes, key=lambda nodeinfo: nodeinfo['cpustat']):
    print(node['vip'])
    x += 1
    if x == nodecount:
        exit(0)
exit(0)
