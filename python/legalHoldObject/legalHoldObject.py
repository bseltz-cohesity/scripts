#!/usr/bin/env python
"""add remove legal hold per object"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

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
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-jn', '--jobname', action='append', type=str)
parser.add_argument('-jl', '--joblist', type=str)
parser.add_argument('-on', '--objectname', action='append', type=str)
parser.add_argument('-ol', '--objectlist', type=str)
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-a', '--addhold', action='store_true')
parser.add_argument('-r', '--removehold', action='store_true')
parser.add_argument('-l', '--includelogs', action='store_true')
parser.add_argument('-y', '--daysback', type=int, default=None)
parser.add_argument('-s', '--startdate', type=str, default=None)
parser.add_argument('-e', '--enddate', type=str, default=None)
parser.add_argument('-rd', '--rundate', type=str, default=None)
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
objectnames = args.objectname
objectlist = args.objectlist
numruns = args.numruns
addhold = args.addhold
removehold = args.removehold
includelogs = args.includelogs
daysback = args.daysback
startdate = args.startdate
enddate = args.enddate
rundate = args.rundate

def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [int(s.strip()) for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items

jobnames = gatherList(jobnames, joblist, name='jobs', required=True)
objectnames = gatherList(objectnames, objectlist, name='objects', required=True)

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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
enddateusecs = nowUsecs

tail = ''
if daysback is not None:
    daysBackUsecs = timeAgo(daysback, 'days')
    tail = '&startTimeUsecs=%s' % daysBackUsecs
startdateusecs = 0
if startdate is not None:
    startdateusecs = dateToUsecs(startdate)
    tail = '&startTimeUsecs=%s' % startdateusecs
if enddate is not None:
    enddateusecs = dateToUsecs(enddate)

jobs = api('get', 'data-protect/protection-groups?isActive=true&pruneSourceIds=true&pruneExcludedSourceIds=true', v=2)
if jobs['protectionGroups'] is not None:
    jobs = [j for j in jobs['protectionGroups'] if j['name'].lower() in [n.lower() for n in jobnames]]
else:
    print('no jobs on cluster')
    exit()
notfoundjobs = [j for j in jobnames if j.lower() not in [j['name'].lower() for j in jobs]]
for notfoundjob in notfoundjobs:
    print('job %s not found' % notfoundjob)

foundobjects = []
for job in sorted(jobs, key=lambda job: job['name'].lower()):
    print('%s' % job['name'])
    endUsecs = enddateusecs
    lastRunId = '0'
    while 1:
        runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeObjectDetails=true%s' % (job['id'], numruns, endUsecs, tail), v=2)
        if lastRunId != '0':
            runs['runs'] = [r for r in runs['runs'] if r['id'] < lastRunId]
        for run in runs['runs']:
            if 'isLocalSnapshotsDeleted' not in run or run['isLocalSnapshotsDeleted'] is not True:
                if 'localBackupInfo' in run:
                    runInfo = run['localBackupInfo']
                    snapInfo = 'localSnapshotInfo'
                else:
                    continue
                # elif 'originalBackupInfo' in run:
                #     runInfo = run['originalBackupInfo']
                #     snapInfo = 'originalBackupInfo'
                # else:
                #     runInfo = run['archivalInfo']['archivalTargetResults'][0]
                #     snapInfo = 'cad'
                runType = runInfo['runType']
                runStartTimeUsecs = runInfo['startTimeUsecs']
                status = runInfo['status']
                if runStartTimeUsecs < startdateusecs:
                    break
                if not includelogs and runType == 'kLog':
                    continue
                thisRundate = usecsToDate(runStartTimeUsecs)
                if rundate and thisRundate != rundate:
                    continue
                print("    %s" % thisRundate)
                if 'objects' in run and sorted(run['objects'], key=lambda object: object['object']['name'].lower()) is not None:
                    for object in run['objects']:
                        # if snapInfo == 'cad':
                        #     object['cad'] = {'snapshotInfo': object['archivalInfo']['archivalTargetResults'][0]}
                        #     object['onLegalHold'] = object['archivalInfo']['archivalTargetResults'][0]['onLegalHold']
                        if object['object']['name'].lower() in [o.lower() for o in objectnames]:
                            if object['object']['name'] not in foundobjects:
                                foundobjects.append(object['object']['name'])
                            onLegalHold = False
                            if 'onLegalHold' in object and object['onLegalHold'] is True:
                                onLegalHold = True
                                if removehold:
                                    if snapInfo in object and object[snapInfo] is not None:
                                        if 'snapshotInfo' in object[snapInfo] and object[snapInfo]['snapshotInfo'] is not None:
                                            snapshotId = object[snapInfo]['snapshotInfo']['snapshotId']
                                            api('put','data-protect/objects/%s/snapshots/%s' % (object['object']['id'], snapshotId), {"setLegalHold": False}, v=2)
                                            print('        %s  ->  removing hold' % object['object']['name'])
                                else:
                                    print("        %s  ->  On Hold" % object['object']['name'])
                            else:
                                if addhold:
                                    if snapInfo in object and object[snapInfo] is not None:
                                        if 'snapshotInfo' in object[snapInfo] and object[snapInfo]['snapshotInfo'] is not None:
                                            snapshotId = object[snapInfo]['snapshotInfo']['snapshotId']
                                            api('put','data-protect/objects/%s/snapshots/%s' % (object['object']['id'], snapshotId), {"setLegalHold": True}, v=2)
                                            print('        %s  ->  adding hold' % object['object']['name'])
                                else:
                                    print("        %s  ->  Not On Hold" % object['object']['name'])
        if len(runs['runs']) == 0 or runs['runs'][-1]['id'] == lastRunId:
            break
        else:
            lastRunId = runs['runs'][-1]['id']
            if 'localBackupInfo' in runs['runs'][-1]:
                endUsecs = runs['runs'][-1]['localBackupInfo']['endTimeUsecs']
            elif 'originalBackupInfo' in runs['runs'][-1]:
                endUsecs = runs['runs'][-1]['originalBackupInfo']['endTimeUsecs']
            else:
                endUsecs = runs['runs'][-1]['archivalInfo']['archivalTargetResults'][0]['endTimeUsecs']
        if endUsecs < startdateusecs:
            break
for object in objectnames:
    if object.lower() not in [n.lower() for n in foundobjects]:
        print('%s not found' % object)
