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
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--nodeId', type=int, default=0)
parser.add_argument('-i', '--ipAddress', type=str, default='')
parser.add_argument('-p', '--ipmiAddress', type=str, default='')
parser.add_argument('-v', '--newVip', type=str, default='')

args = parser.parse_args()

server = args.server
username = args.username
domain = args.domain
nodeId = args.nodeId
ipAddress = args.ipAddress
ipmiAddress = args.ipmiAddress
newVip = args.newVip


### ip validate functions
def ipToBinary(ip):
    return ''.join(['{0:08b}'.format(int(octet)) for octet in ip.split('.')])


def ipValid(newIp, oldIp, netMask):
    cidr = ipToBinary(netMask).index('0')
    if('1' not in ipToBinary(newIp)[cidr:]):
        return False
    if('0' not in ipToBinary(newIp)[cidr:]):
        return False
    return ipToBinary(newIp)[0:cidr] == ipToBinary(oldIp)[0:cidr]


### authenticate
apiauth(server, username, domain)

### get cluster config
clusterStat = api('get', '/nexus/cluster/status')
chassisList = []
for chassis in clusterStat['clusterConfig']['proto']['chassisVec']:
    chassisList.append(chassis['name'])

### get free nodes
freeNodes = api('get', '/nexus/avahi/discover_nodes')

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
            print("using %i" % node['nodeId'])
            selectedNode = node
            break

# if no node was specified and no node was in the same chassis, use the first available node
if nodeId == 0 and selectedNode == 0 and foundNode != 0:
    selectedNode = foundNode

# if node was specified but not found, fail
if selectedNode == 0:
    print("Couldn't find node with ID: %i" % nodeId)
    exit()

else:

    ### gather cluster subnet details
    clusterSubnet = clusterStat['clusterConfig']['proto']['clusterSubnet']['ip']
    clusterNetMask = clusterStat['clusterConfig']['proto']['clusterSubnet']['netmaskIp4']
    ipmiSubnet = clusterStat['clusterConfig']['proto']['ipmiConfig']['subnet']['ip']
    ipmiNetMask = clusterStat['clusterConfig']['proto']['ipmiConfig']['subnet']['netmaskIp4']

    ### validate VIP

    partitions = api('get', 'clusterPartitions')

    if(newVip == ''):
        createVip = False
        if(len(partitions[0]['nodeIds']) >= len(partitions[0]['vips'])):
            print("please provide a new VIP")
            exit()
    else:
        createVip = True
        if(not ipValid(newVip, clusterSubnet, clusterNetMask)):
            print("VIP address %s is not in the range of the cluster subnet %s(%s)" % (newVip, clusterSubnet, clusterNetMask))
            exit()

        if(newVip in partitions[0]['vips']):
            print("VIP %s is already in use on the cluster. Please select an unused address" % newVip)
            exit()

    ### validate Node IP
    if ipAddress == '':
        if 'ipAddresses' in selectedNode:
            ipAddress = selectedNode['ipAddresses'][0]
        else:
            print("please provide node ip Address")
            exit()

    if(not ipValid(ipAddress, clusterSubnet, clusterNetMask)):
        print("Node IPAddress %s is not in range of the cluster subnet %s(%s)" % (ipAddress, clusterSubnet, clusterNetMask))
        exit()

    ### validate ipmi IP
    if ipmiAddress == '':
        if 'ipmiIp' in selectedNode and selectedNode['ipmiIp'] != '':
            ipmiAddress = selectedNode['ipmiIp']
        else:
            print("please provide ipmi ip address")
            exit()

    if(not ipValid(ipmiAddress, ipmiSubnet, ipmiNetMask)):
        print("Node ipmi address %s is not in range of the ipmi subnet %s(%s)" % (ipmiAddress, ipmiSubnet, ipmiNetMask))
        exit()

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

    ### add the vip
    if(createVip):
        print("adding VIP %s" % newVip)
        partitions[0]['vips'].append(newVip)
        vipresult = api('put', '/clusterPartitions/%i' % partitions[0]['id'], partitions[0])

    ### execute the node add
    print("Adding node %i to cluster" % selectedNode['nodeId'])

    result = api('post', '/nexus/cluster/expand', newNodeParams)
    if 'message' in result:
        print(result['message'])
    else:
        display(result)
