#!/usr/bin/env python
"""Add Node to Cluster"""

### usage:
### ./nodeAdd.py -v 10.1.1.211 -u admin # will choose a free node that is in the same chassis
### ./nodeAdd.py -v 10.1.1.211 -u admin -n nodeID # will try to use free node with specified ID
### ./nodeAdd.py -v 10.1.1.211 -u admin -i 10.0.0.12 -p 10.0.0.13 # provide IP and IPMI addresses
                                                                  # or will use existing addresses

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v','--vip', type=str, required=True)
parser.add_argument('-u','--username', type=str, required=True)
parser.add_argument('-d','--domain',type=str, default='local')
parser.add_argument('-n','--nodeId', type=int, default=0)
parser.add_argument('-i','--ipAddress', type=int, default=0)
parser.add_argument('-p','--ipmiAddress', type=int, default=0)

args = parser.parse_args()
    
vip = args.vip
username = args.username
domain = args.domain
nodeId = args.nodeId
ipAddress = args.ipAddress
ipmiAddress = args.ipmiAddress

### authenticate
apiauth(vip, username, domain)

### get cluster config
clusterStat = api('get','/nexus/cluster/status')
chassisList = []
for chassis in clusterStat['clusterConfig']['proto']['chassisVec']:
    chassisList.append(chassis['name'])

### get free nodes
freeNodes = api('get','/nexus/avahi/discover_nodes')

selectedNode = 0
foundNode = 0

for node in freeNodes['freeNodes']:

    if foundNode == 0:
        foundNode = node

    if nodeId == 0:
        ### see if node is in one of our chassis
        if(node['chassisSerial'] in chassisList):
            selectedNode = node
            break
    else:
        ### see if this is the node specified from the commandLine
        if(node['nodeId'] == nodeId):
            print "using %i" % node['nodeId']
            selectedNode = node
            break

# if no node was specified and no node was in the same chassis, use the first available node
if nodeId == 0 and selectedNode == 0 and foundNode != 0:
    selectedNode = foundNode

# if node was specified but not found, fail
if selectedNode == 0:
    print "Couldn't find node with ID: %i" % nodeId
    exit()

else:
    print "Adding node %i to cluster" % selectedNode['nodeId']
    
    ### use specified addresses or get existing addresses from node 
    if ipAddress == 0:
        if 'ipAddresses' in selectedNode:
            ipAddress = selectedNode['ipAddresses'][0]
        else:
            print "please provide node ip Address"
            exit()
    if ipmiAddress == 0:
        if 'ipmiIp' in selectedNode:
            ipmiAddress = selectedNode['ipmiIp']
        else:
            print "please provide ipmi ip address"
            exit()

    ### calculate subnet
    # not sure if API will validate the IP address or not...

    ### new node parameters
    newNodeParams = {
        "nodes": [
            {
                "id": selectedNode['nodeId'],
                "ip": ipAddress,
                "ipmiIp": ipmiAddress
            }
        ],
        "clusterPartitionId": clusterStat['clusterConfig']['proto']['clusterPartitionVec'][0]['id'],
        "autoUpdate": True,
        "ignoreSwIncompatibility": True
    }

    ### execute the node add
    result = api('post','/nexus/cluster/expand',newNodeParams)
    if 'message' in result:
        print result['message']
    else:
        display(result)
