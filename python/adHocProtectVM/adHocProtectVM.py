#!/usr/bin/env python
"""Discover New VM And Backup Now Once"""

### usage: ./adHocProtectVM.py -v mycluster -u myuser [-d mydomain.net] -vc vCenter6.mydomain.net -vm wiki -job 'vm backup' -k 30

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-vc', '--vcenter', type=str, required=True)
parser.add_argument('-vm', '--vmname', type=str, required=True)
parser.add_argument('-job', '--jobname', type=str, required=True)
parser.add_argument('-k', '--daysToKeep', type=int, required=True)

args = parser.parse_args()

vip = args.vip                 # cluster name/ip
username = args.username       # username to connect to cluster
domain = args.domain           # domain of username (e.g. local, or AD domain)
vcenter = args.vcenter         # name of vcenter to find vm on
vmname = args.vmname           # name of VM to add to protection job
jobname = args.jobname         # name of protection job to add VM to
daysToKeep = args.daysToKeep

### authenticate
apiauth(vip, username, domain)

### find vCenter
vCenterId = None
vCenters = api('get', '/entitiesOfType?environmentTypes=kVMware&vmwareEntityTypes=kVCenter')
for vc in vCenters:
    if vc['displayName'].lower() == vcenter.lower():
        vCenterId = vc['id']

if vCenterId is None:
    print('Warning: vCenter %s not found!' % vcenter)
    exit()

### refresh vCenter
print('refreshing %s...' % vcenter)
result = api('post', 'protectionSources/refresh/%s' % vCenterId)

foundJob = False
foundVM = False
myJob = None
for job in api('get', 'protectionJobs'):
    ### find job
    if job['name'].lower() == jobname.lower():
        foundJob = True
        jobId = job['id']
        policyId = job['policyId']
        for vm in api('get', 'protectionSources/virtualMachines?vCenterId=%s' % job['parentSourceId']):
            ### find VM
            if vm['name'].lower() == vmname.lower():
                foundVM = True
                vmId = vm['id']
                ### avoid duplicate
                if vm['id'] in job['sourceIds']:
                    print('VM %s already in job %s' % (vm['name'], job['name']))
                else:
                    ### record old state of job
                    myJob = job
                    mySources = []
                    mySources.extend(job['sourceIds'])
                    ### add VM to job
                    job['sourceIds'].append(vm['id'])
                    print('adding %s to %s job...' % (vm['name'], job['name']))
                    updatedJob = api('put', 'protectionJobs/%s' % job['id'], job)

### report not founds
if foundJob is False:
    print('Warning: Job %s not found!' % jobname)
    exit()
if foundVM is False:
    print('Warning: VM %s not found!' % vmname)
    exit()

### job data
jobData = {
    "copyRunTargets": [
        {
            "type": "kLocal",
            "daysToKeep": daysToKeep
        }
    ],
    "sourceIds": [
        vmId
    ],
    "runType": "kRegular"
}

runs = api('get', 'protectionRuns?jobId=%s' % jobId)
newRunId = lastRunId = runs[0]['backupRun']['jobRunId']

### wait for existing job run to finish
finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
if (runs[0]['copyRun'][0]['status'] not in finishedStates):
    print("waiting for existing job run to finish...")
    while (runs[0]['copyRun'][0]['status'] not in finishedStates):
        sleep(5)
        runs = api('get', 'protectionRuns?jobId=%s' % jobId)

### run protectionJob
print('Running %s...' % jobname)
api('post', 'protectionJobs/run/%s' % jobId, jobData)

### wait for new job run to appear
while(newRunId == lastRunId):
    sleep(1)
    runs = api('get', 'protectionRuns?jobId=%s' % jobId)
    newRunId = runs[0]['backupRun']['jobRunId']

### wait for job run to finish
while(runs[0]['copyRun'][0]['status'] not in finishedStates):
    sleep(5)
    runs = api('get', 'protectionRuns?jobId=%s' % jobId)

### remove vm from job
if myJob is not None:
    myJob['sourceIds'] = mySources
    updatedJob = api('put', 'protectionJobs/%s' % myJob['id'], myJob)

runURL = 'https://%s/protection/job/%s/run/%s/%s/protection' % (vip, runs[0]['jobId'], runs[0]['backupRun']['jobRunId'], runs[0]['copyRun'][0]['runStartTimeUsecs'])
print('RunID: %s Status: %s' % (newRunId, runs[0]['backupRun']['status']))
print('Run URL: %s' % runURL)
