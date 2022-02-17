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
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-l', '--listgflags', action='store_true')
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
listgflags = args.listgflags
folder = args.outfolder
useApiKey = args.useApiKey

GiB = 1024 * 1024 * 1024

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if password is None:
    password = pw(vip=vip, username=username, domain=domain)

cluster = api('get', 'cluster?fetchStats=true')
version = cluster['clusterSoftwareVersion'].split('_')[0]

dateString = datetime.datetime.now().strftime("%Y-%m-%d")
outfileName = '%s/%s-%s-clusterInfo.txt' % (folder, dateString, cluster['name'])
f = codecs.open(outfileName, 'w', 'utf-8')

status = api('get', '/nexus/cluster/status')
config = status['clusterConfig']['proto']
nodeStatus = status['nodeStatus']
nodes = api('get', 'nodes')
if config is not None:
    chassisList = config['chassisVec']
    nodeList = config['nodeVec']
    hostName = status['clusterConfig']['proto']['clusterPartitionVec'][0]['hostName']
else:
    chassisList = (api('get', 'chassis', v=2))['chassis']
    partition = api('get', 'clusterPartitions')
    hostName = partition[0]['hostName']

title = 'clusterInfo: %s (%s)' % (cluster['name'], dateString)


def output(mystring):
    print(mystring)
    f.write(mystring + '\n')


physicalCapacity = round((float(cluster['stats']['usagePerfStats']['physicalCapacityBytes']) / GiB), 1)
usedCapacity = round((float(cluster['stats']['usagePerfStats']['totalPhysicalUsageBytes'] / GiB)), 1)
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

if version >= '6.4':
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
            apiauth(node['ip'].split(':')[-1], username, domain, password=password, quiet=True, useApiKey=useApiKey)
            nodeInfo = api('get', '/nexus/node/hardware_info')
            output('\n            Node ID: %s' % node['id'])
            output('            Node IP: %s' % node['ip'].split(':')[-1])
            output('            IPMI IP: %s' % nodeipmi[0].get('nodeIpmiIp', 'n/a'))
            output('            Slot No: %s' % node.get('slotNumber', 0))
            output('          Serial No: %s' % nodeInfo.get('cohesityNodeSerial', 'VirtualEdition'))
            output('      Product Model: %s' % nodeInfo['productModel'])
            output('         SW Version: %s' % node['nodeSoftwareVersion'])
            for stat in nodeStatus:
                if stat['nodeId'] == node['id']:
                    output('             Uptime: %s' % stat['uptime'])
elif version > '6.3.1f':
    for chassis in chassisList:
        # chassis info
        if 'name' in chassis:
            chassisname = chassis['name']
        else:
            chassisname = chassis['serial']
        output('\n   Chassis Name: %s' % chassisname)
        output('     Chassis ID: %s' % chassis['id'])
        output('       Hardware: %s' % chassis.get('hardwareModel', 'VirtualEdition'))
        gotSerial = False
        for node in nodeList:
            if node['chassisId'] == chassis['id']:
                # node info
                apiauth(node['ip'].split(':')[-1], username, domain, password=password, quiet=True, useApiKey=useApiKey)
                nodeInfo = api('get', '/nexus/node/hardware_info')
                if gotSerial is False:
                    output(' Chassis Serial: %s' % nodeInfo['cohesityChassisSerial'])
                    gotSerial = True
                output('\n            Node ID: %s' % node['id'])
                output('            Node IP: %s' % node['ip'].split(':')[-1])
                output('            IPMI IP: %s' % node.get('ipmiIp', 'n/a'))
                output('            Slot No: %s' % node.get('slotNumber', 0))
                output('          Serial No: %s' % nodeInfo.get('cohesityNodeSerial', 'VirtualEdition'))
                output('      Product Model: %s' % nodeInfo['productModel'])
                output('         SW Version: %s' % node['softwareVersion'])
                for stat in nodeStatus:
                    if stat['nodeId'] == node['id']:
                        output('             Uptime: %s' % stat['uptime'])
else:
    for chassis in chassisList:
        # chassis info
        output('  Chassis Name: %s' % chassis['name'])
        output('    Chassis ID: %s' % chassis['id'])
        output('      Hardware: %s' % chassis.get('hardwareModel', 'VirtualEdition'))
        gotSerial = False
        for node in nodeList:
            if node['chassisId'] == chassis['id']:
                # node info
                nodeInfo = requests.get('http://' + node['ip'].split(':')[-1] + ':23456/nexus/v1/node/info')
                nodeJson = nodeInfo.json()
                if gotSerial is False:
                    output('Chassis Serial: %s' % nodeJson['chassisSerial'])
                    gotSerial = True
                output('\n           Node ID: %s' % node['id'])
                output('           Node IP: %s' % node['ip'].split(':')[-1])
                output('           IPMI IP: %s' % nodeJson.get('ipmiIp', 'n/a'))
                productModel = nodeJson['productModel']

                output('           Slot No: %s' % node.get('slotNumber', 0))
                output('         Serial No: %s' % node.get('serialNumber', 'VirtualEdition'))
                output('     Product Model: %s' % productModel)
                output('        SW Version: %s' % node['softwareVersion'])
                for stat in nodeStatus:
                    if stat['nodeId'] == node['id']:
                        output('            Uptime: %s\n' % stat['uptime'])

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
