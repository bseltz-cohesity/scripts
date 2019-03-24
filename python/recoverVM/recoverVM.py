#!/usr/bin/env python
"""Recover VM for python"""

### usage: ./recoverVM.sh -v mycluster -u admin -vm centos1

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-vm', '--vmName', type=str, required=True)
parser.add_argument('-s', '--suffix', type=str, default='')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
vmName = args.vmName
suffix = args.suffix

### authenticate
apiauth(vip, username, domain)

### find VM
results = api('get', 'restore/objects?search=%s' % vmName)

# vm = None

### latest snapshot where name is exact match
if results['totalCount'] > 0:
    vm = max([vm for vm in results['objectSnapshotInfo'] if vm['objectName'].lower() == vmName.lower()], key=lambda vm: vm['versions'][0]['startedTimeUsecs'])

### restore task parameters
if(vm):

    restoreTask = {
        'name': 'myNewVM',
        'type': 'kRecoverVMs',
        'Objects': [
            {
                "protectionSourceId": vm['snapshottedSource']['id'],
                'jobId': vm['jobId']
            }
        ]
    }

    if suffix:
        restoreTask['vmwareParameters'] = {'suffix': '-' + suffix}
        print("Recovering %s as %s..." % (vmName, vmName + '-' + suffix))
    else:
        print("Recovering %s" % vmName)

### post restore task
    recoveryStatus = api('post', 'restore/recover', restoreTask)
    print("Recovery status: %s" % recoveryStatus['status'])

else:
    print("VM %s not found" % vmName)
