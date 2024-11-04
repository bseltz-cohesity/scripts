#!/usr/bin/env python
"""Create a Cohesity Cluster Using python"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-n', '--nodeid', action='append', type=int, required=True)
parser.add_argument('-v', '--vip', action='append', type=str, required=True)
parser.add_argument('-c', '--clustername', type=str, required=True)
parser.add_argument('-ntp', '--ntpserver', action='append', type=str, required=True)
parser.add_argument('-dns', '--dnsserver', action='append', type=str, required=True)
parser.add_argument('-e', '--encrypt', action='store_true')
parser.add_argument('-cd', '--clusterdomain', type=str, required=True)
parser.add_argument('-z', '--dnsdomain', action='append', type=str)
parser.add_argument('-gw', '--clustergateway', type=str, required=True)
parser.add_argument('-m', '--clustermask', type=str, required=True)
parser.add_argument('-igw', '--ipmigateway', type=str, required=True)
parser.add_argument('-im', '--ipmimask', type=str, required=True)
parser.add_argument('-iu', '--ipmiusername', type=str, required=True)
parser.add_argument('-ip', '--ipmipassword', type=str, required=True)
parser.add_argument('-rp', '--rotationalpolicy', type=int, default=90)
parser.add_argument('-f', '--fips', action='store_true')
parser.add_argument('-x', '--skipcreate', action='store_true')
parser.add_argument('-k', '--licensekey', type=str, required=True)

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
nodeids = list(args.nodeid)
vips = list(args.vip)
clustername = args.clustername
ntpservers = list(args.ntpserver)
dnsservers = list(args.dnsserver)
encrypt = args.encrypt
clusterdomain = args.clusterdomain
dnsdomains = [clusterdomain]
if args.dnsdomain is not None:
    dnsdomains = [clusterdomain] + list(args.dnsdomain)
clustergateway = args.clustergateway
clustermask = args.clustermask
ipmigateway = args.ipmigateway
ipmimask = args.ipmimask
ipmiusername = args.ipmiusername
ipmipassword = args.ipmipassword
rotationalpolicy = args.rotationalpolicy
fips = args.fips
hostname = clustername + '.' + clusterdomain
skipcreate = args.skipcreate
licensekey = args.licensekey

### authenticate
apiauth(vip, username, domain)

### Cluster create parameters
ClusterBringUpReq = {
    "clusterName": clustername,
    "ntpServers": ntpservers,
    "dnsServers": dnsservers,
    "domainNames": dnsdomains,
    "clusterGateway": clustergateway,
    "clusterSubnetCidrLen": clustermask,
    "ipmiGateway": ipmigateway,
    "ipmiSubnetCidrLen": ipmimask,
    "ipmiUsername": ipmiusername,
    "ipmiPassword": ipmipassword,
    "enableEncryption": encrypt,
    "rotationalPolicy": rotationalpolicy,
    "enableFipsMode": fips,
    "nodes": [],
    "clusterDomain": clusterdomain,
    "hostname": hostname,
    "vips": vips
}

### gather node info
if skipcreate is not True:
    # wait for all requested nodes to be free
    nodecount = 0
    while nodecount < len(nodeids):
        nodes = api('get', '/nexus/avahi/discover_nodes')
        for freenode in nodes['freeNodes']:
            if freenode['nodeId'] in nodeids:
                nodecount += 1
        print("%s of %s free nodes found" % (nodecount, len(nodeids)))
        if nodecount < len(nodeids):
            sleep(10)

    for freenode in nodes['freeNodes']:
        for nodeid in nodeids:

            # gather node IP info
            if nodeid == freenode['nodeId']:

                if 'ipAddresses' in freenode:
                    ip = freenode['ipAddresses'][0]
                else:
                    print('node %s has no IP address' % nodeid)
                    exit(1)

                if 'ipmiIp' in freenode:
                    ipmiip = freenode['ipmiIp']
                else:
                    print('node %s has no IPMI IP address' % nodeid)
                    exit(1)

                # add node to Cluster parameters
                node = {
                    "id": nodeid,
                    "ip": ip,
                    "ipmiIp": ipmiip
                }

                ClusterBringUpReq['nodes'].append(node)

### create the cluster
if skipcreate is not True:
    print("Creating Cluster %s..." % clustername)
    result = api('post', '/nexus/cluster/bringup', ClusterBringUpReq)

### wait for cluster to come online
print("Waiting for cluster creation...")
clusterId = None
while clusterId is None:
    sleep(5)
    apiauth(vip, username, domain, quiet=True)
    if(apiconnected() is True):
        cluster = api('get', 'cluster', quiet=True)
        if cluster is not None:
            if 'errorCode' not in cluster:
                clusterId = cluster['id']

print("New Cluster ID is: %s" % clusterId)
apidrop()

### wait for services to be started
print("Waiting for services to start...")
synced = False
while synced is False:
    sleep(5)
    apiauth(vip, username, domain, quiet=True)
    if(apiconnected() is True):
        stat = api('get', '/nexus/cluster/status', quiet=True)
        if stat is not None:
            if stat['isServiceStateSynced'] is True:
                synced = True
                print('Cluster Services are Started')

### accept eula and apply license key
print("Accepting EULA and Applying License Key...")
now = datetime.now()
nowUsecs = dateToUsecs(now.strftime('%Y-%m-%d %H:%M:%S'))
nowMsecs = int(round(nowUsecs / 1000000))
agreement = {
    "signedVersion": 2,
    "signedByUser": "admin",
    "signedTime": nowMsecs,
    "licenseKey": licensekey
}
api('post', '/licenseAgreement', agreement)
print("Cluster Creation Successful!")
