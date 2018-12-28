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
results = api('get','restore/objects?search=%s' % vmName)

vms = []

if results['totalCount'] > 0: # filter on exact name match then sort by newest snapshot
    vms = filter( lambda vm: vm['objectName'].lower() == vmName.lower(), results['objectSnapshotInfo'] )
    vms.sort( key=lambda vm: vm['versions'][0]['startedTimeUsecs'], reverse=True )

if(len(vms)):

    restoreTask = {
        'name': 'myNewVM',
        'type': 'kRecoverVMs',
        'Objects': [
            {
                "protectionSourceId": vms[0]['snapshottedSource']['id'],
                'jobId': vms[0]['jobId']
            }
        ]
    }

    if suffix:
        restoreTask['vmwareParameters'] = {'suffix': '-' + suffix}
        print "recovering %s as %s..." % (vmName, vmName + '-' + suffix)
    else:
        print "recovering %s" % vmName

    recoveryStatus = api('post', 'restore/recover', restoreTask)
    print "Recovery status: %s" % recoveryStatus['status']

else:
     print "VM %s not found" % vmName


