#!/usr/bin/env python
"""pause or resume protection jobs"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-j', '--jobName', action='append', type=str)
parser.add_argument('-l', '--jobList', type=str)
parser.add_argument('-r', '--resume', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
jobNames = args.jobName
jobList = args.jobList
useApiKey = args.useApiKey
resume = args.resume

# gather job names
if jobNames is None:
    jobNames = []
if jobList is not None:
    f = open(jobList, 'r')
    jobNames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

if resume is True:
    action = 'kResume'
    actiontext = 'Resuming'
else:
    action = 'kPause'
    actiontext = 'Pausing'

jobIds = []

for jobName in jobNames:

    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:
        job = job[0]
        print("%s - %s" % (actiontext, job['name']))
        jobIds.append(job['id'])

if len(jobIds) > 0:
    result = api('post', 'protectionJobs/states', {"action": action, "jobIds": jobIds})
