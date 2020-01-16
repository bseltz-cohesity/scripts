#!/usr/bin/env python
"""List Recovery Points for python"""

### usage: ./clusterInfo.py -v mycluster -u admin [-d local]

### import pyhesity wrapper module
from pyhesity import *
import datetime
import requests

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

### authenticate
apiauth(vip, username, domain)

dateString = datetime.datetime.now().strftime("%c").replace(':', '-').replace(' ', '_')
outfileName = 'clusterInfo-%s-%s.txt' % (vip, dateString)
f = open(outfileName, "w")

status = api('get', '/nexus/cluster/status')
config = status['clusterConfig']['proto']
chassisList = config['chassisVec']
nodeList = config['nodeVec']
nodeStatus = status['nodeStatus']
diskList = config['diskVec']


def output(mystring):
    print(mystring)
    f.write(mystring + '\n')


# cluster info
output('\n------------------------------------')
output('    Cluster Name: %s' % status['clusterConfig']['proto']['clusterPartitionVec'][0]['hostName'])
output('      Cluster ID: %s' % status['clusterId'])
output('  Healing Status: %s' % status['healingStatus'])
output('    Service Sync: %s' % status['isServiceStateSynced'])
output('Stopped Services: %s' % status['bulletinState']['stoppedServices'])
output('------------------------------------\n')
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

f.close()
