#!/usr/bin/env python
"""Remove Node from Cluster"""

### usage: ./backupNow.py -v mycluster -u admin -j 'VM Backup'

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--nodeId', type=int, default=0)
parser.add_argument('-m', '--maxFull', type=int, default=70)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
nodeId = args.nodeId
maxFull = args.maxFull

### authenticate
apiauth(vip, username, domain)

### get cluster stats
cluster = api('get', 'cluster?fetchStats=true')

### check minimum node count
if cluster['nodeCount'] == cluster['supportedConfig']['minNodesAllowed']:
    print("Can not remove a node. Current node count: %i (Minimum required: %i)" % (cluster['nodeCount'], cluster['supportedConfig']['minNodesAllowed']))
    exit()

### check free space
newCapacity = cluster['stats']['usagePerfStats']['physicalCapacityBytes'] / cluster['nodeCount'] * (cluster['nodeCount'] - 1) * maxFull / 100

if cluster['stats']['usagePerfStats']['systemUsageBytes'] > newCapacity:
    print("Can not remove a node. Resulting capacity would be below the maxFull threshold")
    exit()

### check cluster health
clusterStat = api('get', '/nexus/cluster/status')
if clusterStat['healingStatus'] != 'NORMAL':
    print("Can not remove a node. Cluster Health Status is abnormal")
    exit()

### get node for removal
selectedNodeId = 0
nodeList = sorted(clusterStat['clusterConfig']['proto']['nodeVec'], key=lambda kv: kv['clusterNodeIndex'], reverse=True)

### if node is not specified, select last node of cluster
if nodeId == 0:
    selectedNodeId = nodeList[0]['id']
else:
    ### otherwise find specified node
    for node in nodeList:
        if nodeId == node['id']:
            selectedNodeId = nodeId
            break

### if we couldn't find the specified node
if selectedNodeId == 0:
    print("Couldn't find a node to remove")
else:
    ### remove the selected node
    print("Removing node %i" % selectedNodeId)
    result = api('post', "/nodes/%i" % selectedNodeId)
