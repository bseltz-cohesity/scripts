#!/usr/bin/env python
"""Recover VM for python"""

### usage: ./recoverVM.sh -v mycluster -u admin -vm centos1

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v','--vip', type=str, required=True)
parser.add_argument('-u','--username', type=str, required=True)
parser.add_argument('-d','--domain',type=str,default='local')
parser.add_argument('-vm','--vmName', type=str, required=True)
parser.add_argument('-s','--suffix',type=str,default='')

args = parser.parse_args()
    
vip = args.vip
username = args.username
domain = args.domain
vmName = args.vmName
suffix = args.suffix

### authenticate
apiauth(vip, username, domain)

### find VM
vms = api('get','restore/objects?search=%s' % vmName)

if vms['totalCount'] == 0:
    print "VM '%s' not found" % vmName
    exit()

if vms['totalCount'] > 1:
    for vm in vms['objectSnapshotInfo']:
        if vm['snapshottedSource']['name'].lower() == vmName.lower():
            exactvm = vm

if vms['totalCount'] == 1:
    exactvm = vms['objectSnapshotInfo'][0]

vmId = exactvm['snapshottedSource']['id']
jobId = exactvm['jobId']

if vmId:
    restoreTask = {
        'name': 'myNewVM',
        'type': 'kRecoverVMs',
        'Objects': [
            {
                "protectionSourceId": vmId,
                'jobId': jobId
            }
        ]
    }

if suffix:
    restoreTask['vmwareParameters'] = {'suffix': '-' + suffix}
    print "recovering %s as %s..." % (vmName, vmName + '-' + suffix)
else:
    print "recovering %s" % vmName

recoveryStatus = api('post','restore/recover', restoreTask)
print "Status: %s" % recoveryStatus['status']
