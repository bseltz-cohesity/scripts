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


# now = datetime.now()
# nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
# cluster = api('get', 'cluster')
# dateString = now.strftime("%Y-%m-%d")

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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true', v=2)

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
    print('%s' % job['name'])
    run = api('get', 'data-protect/protection-groups/%s/runs/%s?includeObjectDetails=true&includeTenants=true' % (job['id'], job['lastRun']['id']), v=2) 
    if run is not None:
        for obj in run['objects']:
            objName = obj['object']['name']
            objId = obj['object']['id']
            if 'warnings' in obj['localSnapshotInfo']['snapshotInfo'] and obj['localSnapshotInfo']['snapshotInfo']['warnings'] is not None and len(obj['localSnapshotInfo']['snapshotInfo']['warnings']) > 0:
                thisFile = '%s-%s-%s' % (job['name'].replace(" ","-"), objName.replace("\\","-").replace("/","-").replace(":","-").replace(" ","-"), "warnings.csv")
                print("    %s -> %s" % (objName, thisFile))
                result = fileDownload(uri="data-protect/protection-groups/%s/runs/%s/objects/%s/downloadMessages" % (job['id'], job['lastRun']['id'], objId) ,fileName=thisFile, v=2)
                f = codecs.open(thisFile, 'a')
                for warning in obj['localSnapshotInfo']['snapshotInfo']['warnings']:
                    f.write(warning)
                f.close()
