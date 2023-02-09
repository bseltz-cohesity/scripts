#!/usr/bin/env python
"""base V2 example"""

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
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-n', '--numruns', type=int, default=100)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobnames = args.jobname
joblist = args.joblist
numruns = args.numruns

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'archivedSnapshots-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Job Name,Run Date,Status,Expired,Archived,ArchiveTarget,ArchiveStatus,ArchiveExpiry,ArchiveCount\n')


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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:

        print('%s' % job['name'])

        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true' % (job['id'], numruns, endUsecs), v=2)
            if len(runs['runs']) > 0:
                endUsecs = int(runs['runs'][-1]['id'].split(':')[1]) - 1
            else:
                break
            for run in runs['runs']:
                runStartTime = usecsToDate(run['id'].split(':')[1])
                status = ''
                expired = ''
                if 'localBackupInfo' in run:
                    # runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
                    status = run['localBackupInfo']['status']
                    expired = False
                if 'isLocalSnapshotsDeleted' in run and run['isLocalSnapshotsDeleted'] is True:
                    expired = True
                archiveTarget = ''
                archiveStatus = ''
                archiveExpires = ''
                archived = False
                archiveCount = 0
                if 'archivalInfo' in run and 'archivalTargetResults' in run['archivalInfo'] and len(run['archivalInfo']['archivalTargetResults']) > 0:
                    archiveTarget = run['archivalInfo']['archivalTargetResults'][-1]['targetName']
                    archiveStatus = run['archivalInfo']['archivalTargetResults'][-1]['status']
                    if 'expiryTimeUsecs' in run['archivalInfo']['archivalTargetResults'][-1]:
                        archiveExpireUsecs = run['archivalInfo']['archivalTargetResults'][-1]['expiryTimeUsecs']
                        if archiveExpireUsecs > nowUsecs:
                            archiveExpires = usecsToDate(archiveExpireUsecs)
                            archived = True
                        else:
                            archiveExpires = 'Expired'
                    archiveCount = len(run['archivalInfo']['archivalTargetResults'])
                print("    %s  %s  Expired: %s Archived: %s (%s)" % (runStartTime, status, expired, archived, archiveCount))
                f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (job['name'], runStartTime, status, expired, archived, archiveTarget, archiveStatus, archiveExpires, archiveCount))

f.close()
print('\nOutput saved to %s\n' % outfile)
