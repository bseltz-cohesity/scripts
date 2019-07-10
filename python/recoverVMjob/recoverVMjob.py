#!/usr/bin/env python
"""Recover VM for python"""

### usage: ./recoverVMjob.py -v mycluster -u admin -j 'VM Backup' -vc vcenter.mydomain.net -vh esxhost1.mydomain.net -ds datastore1 -n 'VM Network' -s recover -f myfolder

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-vc', '--vcentername', type=str, required=True)
parser.add_argument('-vh', '--vhost', type=str, required=True)
parser.add_argument('-ds', '--datastorename', type=str, required=True)
parser.add_argument('-f', '--foldername', type=str, default='vm')
parser.add_argument('-n', '--networkname', type=str, required=True)
parser.add_argument('-s', '--suffix', type=str, default='')
parser.add_argument('-p', '--poweron', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
vcentername = args.vcentername
vhost = args.vhost
datastorename = args.datastorename
foldername = args.foldername
networkname = args.networkname
suffix = args.suffix
poweron = args.poweron

### authenticate
apiauth(vip, username, domain)

### find VM
results = api('get', 'restore/objects?search=%s' % jobname)

vcid = None
### find vCenter
vcenter = [vcenter for vcenter in api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter') if vcenter['displayName'].lower() == vcentername.lower()]

if vcenter:
    vcenterid = vcenter[0]['id']
    vcenterentity = vcenter[0]
else:
    print("vcenter %s not found!" % vcentername)
    exit(1)

### find resource pool
resourcepool = None
hosts = api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kHostSystem')
for host in hosts:
    if host['displayName'].lower() == vhost.lower() and host['parentId'] == vcenterid:
        resourcepoolid = host['id'] + 1
if resourcepoolid is None:
    print("vhost %s not found!" % vhost)
    exit(1)
resourcepoolentity = None
resourcepools = api('get', '/resourcePools?vCenterId=%s' % vcenterid)
for resourcepool in resourcepools:
    if resourcepool['resourcePool']['id'] == resourcepoolid:
        resourcepoolentity = resourcepool['resourcePool']
if resourcepoolentity is None:
    print("vhost %s not found!" % vhost)
    exit(1)

### find datastore
datastoreentity = None
datastores = api('get', '/datastores?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
for datastore in datastores:
    if datastore['displayName'].lower() == datastorename.lower():
        datastoreentity = datastore
if datastoreentity is None:
    print("datastore %s not found!" % datastorename)
    exit(1)

### find VM network
networkentity = None
networks = api('get', '/networkEntities?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
for network in networks:
    if network['displayName'].lower() == networkname.lower():
        networkentity = network
if networkentity is None:
    print("VM network %s not found!" % networkname)
    exit(1)

### find folder
folderentity = None
folders = api('get', '/vmwareFolders?vCenterId=%s&resourcePoolId=%s' % (vcenterid, resourcepoolid))
for folder in folders['vmFolders']:
    if folder['displayName'].lower() == foldername.lower():
        folderentity = folder
if folderentity is None:
    print("VM folder %s not found!" % foldername)
    exit(1)

### latest snapshot where name is exact match
if results['totalCount'] > 0:
    vm = max([vm for vm in results['objectSnapshotInfo'] if vm['jobName'].lower() == jobname.lower()], key=lambda vm: vm['versions'][0]['startedTimeUsecs'])
else:
    print("Job %s not found" % jobname)
    exit(1)

### restore task parameter
if(vm):

    restoreTask = {
        'name': 'myRecoeryTas',
        'Objects': [
            {
                'jobId': vm['jobId']
            }
        ],
        "powerStateConfig": {
            "powerOn": poweron
        },
        "continueRestoreOnError": True,
        "restoreParentSource": vcenterentity,
        "restoredObjectsNetworkConfig": {
            "networkEntity": networkentity,
            "disableNetwork": False
        },
        "resourcePoolEntity": resourcepoolentity,
        "datastoreEntity": datastoreentity,
        "vmwareParams": {
            "targetVmFolder": folderentity
        }
    }

    if suffix:
        restoreTask['renameRestoredObjectParam'] = {"suffix": '-' + suffix}
        print("Recovering %s..." % (jobname))
    else:
        print("Recovering %s" % jobname)

### post restore task
    recoveryStatus = api('post', '/restore', restoreTask)
    print("Recovery Started...")

else:
    print("Job %s not found" % jobname)
