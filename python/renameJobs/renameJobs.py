#!/usr/bin/env python
"""rename protection jobs"""

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
parser.add_argument('-j', '--jobName', type=str, default=None)
parser.add_argument('-n', '--newName', type=str, default=None)
parser.add_argument('-l', '--jobList', type=str)
parser.add_argument('-c', '--commit', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
jobName = args.jobName
newName = args.newName
jobList = args.jobList
useApiKey = args.useApiKey
commit = args.commit

# gather job names
renames = []
if jobName is not None:
    if newName is None:
        print('newName required for job %s' % jobName)
        exit(1)
    renames.append({'jobName': jobName, 'newName': newName})
if jobList is not None:
    f = open(jobList, 'r')
    jobNames = [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
    for j in jobNames:
        jobName, newName = j.split(',')
        renames.append({'jobName': jobName.strip(), 'newName': newName.strip()})

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if apiconnected() is False:
    print('\nFailed to connect to Cohesity cluster')
    exit(1)

jobs = api('get', 'data-protect/protection-groups', v=2)

for rename in renames:
    jobName = rename['jobName']
    newName = rename['newName']
    job = [job for job in jobs['protectionGroups'] if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:
        job = job[0]
        print("Renaming '%s' to '%s'" % (job['name'], newName))
        job['name'] = newName
        if commit is True:
            result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
