#!/usr/bin/env python
"""pause or resume protection jobs"""

### import pyhesity wrapper module
from pyhesity import *
import codecs
import os

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobName', action='append', type=str)
parser.add_argument('-l', '--jobList', type=str)
parser.add_argument('-r', '--resume', action='store_true')
parser.add_argument('-p', '--pause', action='store_true')
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobNames = args.jobName
jobList = args.jobList
pause = args.pause
resume = args.resume
outfolder = args.outfolder

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================


# gather server list
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


jobnames = gatherList(jobNames, jobList, name='jobs', required=False)

jobs = api('get', 'protectionJobs?isActive=true&isDeleted=false')

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if resume is True:
    action = 'kResume'
    actiontext = 'Resuming'
elif pause is True:
    action = 'kPause'
    actiontext = 'Pausing'
else:
    action = 'show'
jobIds = []

cluster = api('get', 'cluster')

if action == 'kPause':
    outfile = os.path.join(outfolder, 'jobsPaused-%s.txt' % cluster['name'])
    f = codecs.open(outfile, 'w')

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:

        if action == 'show':
            if 'isPaused' in job and job['isPaused'] is True:
                print("%s (paused)" % job['name'])
            else:
                print("%s (active)" % job['name'])
        else:
            if ('isPaused' in job and job['isPaused'] is True and action == 'kResume') or (('isPaused' not in job or job['isPaused'] is False) and action == 'kPause'):
                print("%s - %s" % (actiontext, job['name']))
                jobIds.append(job['id'])
                if action == 'kPause':
                    f.write('%s\n' % job['name'])

if len(jobIds) > 0:
    result = api('post', 'protectionJobs/states', {"action": action, "jobIds": jobIds})

if action == 'kPause':
    f.close()
