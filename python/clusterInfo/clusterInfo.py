#!/usr/bin/env python
"""Cluster Info for python"""

# version 2021-11-21

### import pyhesity wrapper module
from pyhesity import *
import datetime
import requests
import codecs
import os.path

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-l', '--listgflags', action='store_true')
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
listgflags = args.listgflags
folder = args.outfolder

GiB = 1024 * 1024 * 1024

def output(mystring):
    print(mystring)
    f.write(mystring + '\n')

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

cluster = api('get', 'cluster?fetchStats=true')
version = cluster['clusterSoftwareVersion'].split('_')[0]

dateString = datetime.datetime.now().strftime("%Y-%m-%d")
outfileName = '%s/%s-%s-clusterInfo.txt' % (folder, dateString, cluster['name'])
f = codecs.open(outfileName, 'w', 'utf-8')

status = api('get', '/nexus/cluster/status')
nodeStatus = status['nodeStatus']
nodes = api('get', 'nodes')

chassisList = (api('get', 'chassis', v=2))['chassis']
partition = api('get', 'clusterPartitions')
hostName = partition[0]['hostName']

title = 'clusterInfo: %s (%s)' % (cluster['name'], dateString)

physicalCapacity = round((float(cluster['stats']['usagePerfStats']['physicalCapacityBytes']) / GiB), 1)
usedCapacity = round((float(cluster['stats']['usagePerfStats']['totalPhysicalUsageBytes'] / GiB)), 1)
usedPct = 0
if physicalCapacity > 0 and usedCapacity > 0:
    usedPct = int(round((100 * usedCapacity / physicalCapacity), 0))

# cluster info
output('\n------------------------------------')
output('     Cluster Name: %s' % hostName)
output('       Cluster ID: %s' % cluster['id'])
output('   Healing Status: %s' % status['healingStatus'])
output('     Service Sync: %s' % status['isServiceStateSynced'])
output(' Stopped Services: %s' % status['bulletinState']['stoppedServices'])
output('Physical Capacity: %s GiB' % physicalCapacity)
output('    Used Capacity: %s GiB' % usedCapacity)
output('     Used Percent: %s%%' % usedPct)
output('------------------------------------')

ipmi = api('get', '/nexus/ipmi/cluster_get_lan_info')
for chassis in chassisList:
    # chassis info
    serial = ''
    if 'serial' in chassis:
        serial = chassis['serial']
    if 'serialNumber' in chassis:
        serial = chassis['serialNumber']
    if 'name' in chassis:
        chassisname = chassis['name']
    else:
        chassisname = chassis['serial']
    output('\n   Chassis Name: %s' % chassisname)
    output('     Chassis ID: %s' % chassis['id'])
    output('       Hardware: %s' % chassis.get('hardwareModel', 'VirtualEdition'))
    output(' Chassis Serial: %s' % serial)
    if 'nodeIds' in chassis:
        nodeIds = chassis['nodeIds']
    else:
        nodeIds = [n['id'] for n in nodes]
    for nodeId in nodeIds:
        node = [n for n in nodes if n['id'] == nodeId][0]
        if 'nodesIpmiInfo' in ipmi:
            nodeipmi = [i for i in ipmi['nodesIpmiInfo'] if i['nodeIp'] == node['ip'].split(':')[-1]]
        else:
            nodeipmi = [{}]
        # node info
        output('\n            Node ID: %s' % node['id'])
        output('            Node IP: %s' % node['ip'].split(':')[-1])
        if len(nodeipmi) > 0:
            output('            IPMI IP: %s' % nodeipmi[0].get('nodeIpmiIp', 'n/a'))
        else:
            output('            IPMI IP: n/a')
        output('            Slot No: %s' % node.get('slotNumber', 0))
        output('          Serial No: %s' % node.get('cohesityNodeSerial', 'Unknown'))
        output('      Product Model: %s' % node.get('productModel', 'Unknown'))                
        output('         SW Version: %s' % node['nodeSoftwareVersion'])
        for stat in nodeStatus:
            if stat['nodeId'] == node['id']:
                output('             Uptime: %s' % stat['uptime'])

if listgflags:
    gflagfileName = '%s/%s-gflags.csv' % (folder, dateString)
    writeheader = True
    if os.path.exists(gflagfileName):
        writeheader = False
    g = codecs.open(gflagfileName, 'a', 'utf-8')
    if writeheader is True:
        g.write('Cluster,Service,gFlag,Value,Reason\n')
    output('\n--------\n Gflags\n--------')
    flags = api('get', '/nexus/cluster/list_gflags')
    for service in flags['servicesGflags']:
        servicename = service['serviceName']
        if len(service['gflags']) > 0:
            output('\n%s:\n' % servicename)
        gflags = service['gflags']
        for gflag in gflags:
            flagname = gflag['name']
            flagvalue = gflag['value']
            reason = gflag['reason']
            output('    %s: %s (%s)' % (flagname, flagvalue, reason))
            g.write('"%s","%s","%s","%s","%s"\n' % (cluster['name'], servicename, flagname, flagvalue, reason))
    g.close()

output('')
f.close()
