#!/usr/bin/env python
"""Backup Now for python"""

# usage: ./backupNowOneObject.sh -v mycluster -u admin -vm centos1 -j 'VM Backup'

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-vm', '--vmname', type=str, required=True)
parser.add_argument('-j', '--jobname', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
vmName = args.vmname
jobName = args.jobname


# authenticate
apiauth(vip, username, domain)

# find VM
vm = [vm for vm in api('get', 'protectionSources/virtualMachines') if vm['name'].lower() == vmName.lower()]
if not vm:
    print("VM '%s' not found" % vmName)
    exit()

# find protectionJob
if jobName:
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
else:
    job = [job for job in api('get', 'protectionJobs') if vm[0]['id'] in job['sourceIds']]
    if len(job) > 1:
        print('%s protected by multiple jobs. Please specify --jobname (-j)' % vmName)
        exit()

if not job:
    print("Job '%s' not found" % jobName)
    exit()

# job data
jobData = {
    "copyRunTargets": [],
    "sourceIds": [
        vm[0]['id']
    ],
    "runType": "kRegular"
}

# run protectionJob
print("Running %s..." % job[0]['name'])
api('post', "protectionJobs/run/%s" % job[0]['id'], jobData)
