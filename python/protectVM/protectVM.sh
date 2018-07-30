#!/usr/bin/env python
"""Change Snapshot Expiration Using Python"""

### usage: ./protectVM.sh -v bseltzve01 -u admin -vm mongodb -job 'vm backup'

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v','--vip', type=str, required=True)
parser.add_argument('-u','--username', type=str, required=True)
parser.add_argument('-d','--domain',type=str,default='local')
parser.add_argument('-vm','--vmname', type=str, required=True)
parser.add_argument('-job','--jobname', type=str, required=True)

args = parser.parse_args()
    
vip = args.vip                 #cluster name/ip
username = args.username       #username to connect to cluster
domain = args.domain           #domain of username (e.g. local, or AD domain)
vmname = args.vmname           #name of VM to add to protection job
jobname = args.jobname         #name of protection job to add VM to

### authenticate
apiauth(vip, username, domain)


foundJob = False
foundVM = False
for job in api('get','protectionJobs'):
    ### find job
    if job['name'].lower() == jobname.lower():
        foundJob = True
        for vm in api('get','protectionSources/virtualMachines?vCenterId=' + str(job['parentSourceId'])):
            ### find VM
            if vm['name'].lower() == vmname.lower():
                foundVM = True
                ### avoid duplicate
                if vm['id'] in job['sourceIds']:
                    print 'VM %s already in job %s' % (vm['name'], job['name'])
                else:
                    ### add VM to job
                    job['sourceIds'].append(vm['id'])
                    print 'adding %s to %s job...' % (vm['name'], job['name'])
                    updatedJob = api('put','protectionJobs/' + str(job['id']),job)
### report not founds
if foundJob == False:
    print 'Warning: Job %s not found!' % jobname
    exit()
if foundVM == False:
    print 'Warning: VM %s not found!' % vmname