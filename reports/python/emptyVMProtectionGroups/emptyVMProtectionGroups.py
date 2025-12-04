#!/usr/bin/env python
"""base V1 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
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
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-a', '--reportall', action='store_true')
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
jobnames = args.jobname
joblist = args.joblist
reportall = args.reportall

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

# outfile
cluster = api('get', 'cluster')
outfile = 'emptyVMProtectionGroups-%s.csv' % cluster['name']
f = codecs.open(outfile, 'w')
f.write('"Protection Group","Number of Objects","Message"\n')

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


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)

jobs = api('get', 'data-protect/protection-groups?environments=kVMware&isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)
if len(jobnames) > 0:
    jobs['protectionGroups'] = [j for j in jobs['protectionGroups'] if j['name'].lower() in [n.lower() for n in jobnames]]

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if 'lastRun' not in job:
        continue
    backup = job['lastRun']['localBackupInfo']
    totalobjects = backup['cancelledObjectsCount'] + backup['failedObjectsCount'] + backup['cancelledAppObjectsCount'] + backup['failedAppObjectsCount'] + backup['successfulAppObjectsCount'] + backup['successfulObjectsCount']
    if totalobjects == 0:
        print('%s (%s) !!!!!' % (job['name'], totalobjects))
        f.write('"%s","%s","Zero Objects Protected!"\n' % (job['name'], totalobjects))
    else:
        print('%s (%s)' % (job['name'], totalobjects))
        if reportall is True:
             f.write('"%s","%s",""\n' % (job['name'], totalobjects))
f.close()
print('\nOutput saved to %s\n' % outfile)