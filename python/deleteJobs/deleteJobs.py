#!/usr/bin/env python
"""delete protection jobs"""

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
parser.add_argument('-s', '--deleteSnapshots', action='store_true')
parser.add_argument('-c', '--commit', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
jobNames = args.jobName
jobList = args.jobList
useApiKey = args.useApiKey
deleteSnapshots = args.deleteSnapshots
commit = args.commit

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

for jobName in jobNames:

    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobName.lower()]
    if not job:
        print("Job '%s' not found" % jobName)
    else:
        job = job[0]
        print("Deleting %s" % job['name'])
        if commit is True:
            result = api('delete', 'protectionJobs/%s' % job['id'], {'deleteSnapshots': deleteSnapshots})
