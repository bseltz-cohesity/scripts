#!/usr/bin/env python
"""unprotect VMs"""

# version 2022-03-05

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-s', '--joblist', type=str)
parser.add_argument('-n', '--vmname', action='append', type=str)
parser.add_argument('-l', '--vmlist', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
vmnames = args.vmname
vmlist = args.vmlist
jobnames = args.jobname
joblist = args.joblist


def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)
vmnames = gatherList(vmnames, vmlist, name='VMs', required=True)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

vmfound = {}
for vm in vmnames:
    vmfound[vm] = False

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    for job in jobs['protectionGroups']:

        if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:

            saveJob = False

            for vm in vmnames:
                protectedObjectCount = len(job['vmwareParams']['objects'])
                job['vmwareParams']['objects'] = [o for o in job['vmwareParams']['objects'] if o['name'].lower() != vm.lower()]
                if len(job['vmwareParams']['objects']) < protectedObjectCount:
                    print('%s removed from from group: %s' % (vm, job['name']))
                    vmfound[vm] = True
                    saveJob = True

            if saveJob is True:
                if len(job['vmwareParams']['objects']) == 0:
                    print('0 objects left in %s. Deleting...' % job['name'])
                    result = api('delete', 'data-protect/protection-groups/%s' % job['id'], v=2)
                else:
                    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

for vm in vmnames:
    if vmfound[vm] is False:
        print('%s not found in any VM protection group. * * * * * *' % vm)
