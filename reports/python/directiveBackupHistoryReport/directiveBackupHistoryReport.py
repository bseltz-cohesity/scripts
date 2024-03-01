#!/usr/bin/env python
"""backed up files list for python"""

# import pyhesity wrapper module
from pyhesity import *
import codecs
import argparse

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-y', '--days', type=int, default=7)

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
numruns = args.numruns
days = args.days

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

daysBackUsecs = timeAgo(days, "days")

outfile = 'directiveBackupHistoryReport.csv'
f = codecs.open(outfile, 'w')
f.write('"Cluster","Protection Group","Start Time","Status","Server","Directive File","Run ID","Link"\n')


def getCluster():

    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])
    jobs = api('get', 'data-protect/protection-groups?environments=kPhysical&isActive=true&isDeleted=false&includeTenants=true', v=2)

    if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
        for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
            if job['physicalParams']['protectionType'] == 'kFile':
                v1JobId = job['id'].split(':')[2]
                startTimeUsecs = daysBackUsecs
                runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&includeTenants=true&startTimeUsecs=%s&includeObjectDetails=true' % (job['id'], numruns, startTimeUsecs), v=2)
                if len(runs['runs']) > 0:
                    print('  %s' % job['name'])
                    for run in runs['runs']:
                        runDetail = None
                        runId = None
                        if 'isLocalSnapshotsDeleted' not in run or run['isLocalSnapshotsDeleted'] is not True:
                            runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
                            for runobject in run['objects']:
                                obj = [o for o in job['physicalParams']['fileProtectionTypeParams']['objects'] if o['name'] == runobject['object']['name']]
                                if runobject is not None and len(runobject) > 0:
                                    status = runobject['localSnapshotInfo']['snapshotInfo']['status'][1:]
                                    if 'metadataFilePath' in obj[0] and obj[0]['metadataFilePath'] is not None:
                                        if runDetail is None:
                                            runDetail = api('get', '/backupjobruns?exactMatchStartTimeUsecs=%s&id=%s' % (run['localBackupInfo']['startTimeUsecs'], v1JobId))
                                            runId = runDetail[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['base']['jobInstanceId']
                                        try:
                                            metadataFilePath = runDetail[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['additionalParamVec'][0]['physicalParams']['metadataFilePath']
                                        except Exception:
                                            metadataFilePath = obj[0]['metadataFilePath']
                                        link = 'https://%s/protection/group/run/backup/%s/%s' % (vip, job['id'], run['id'])
                                        f.write('"%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], runStartTime, status, obj[0]['name'], metadataFilePath, runId, link))


for vip in vips:

    # authentication =========================================================
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

    # exit if not authenticated
    if apiconnected() is False:
        print('authentication failed')
        continue

    # if connected to helios or mcm, select access cluster
    if mcm or vip.lower() == 'helios.cohesity.com':
        if clusternames is None or len(clusternames) == 0:
            clusternames = [c['name'] for c in heliosClusters()]
        for clustername in clusternames:
            heliosCluster(clustername)
            if LAST_API_ERROR() != 'OK':
                continue
            getCluster()
    else:
        getCluster()


f.close()
print('\nOutput saved to %s\n' % outfile)

f.close()
