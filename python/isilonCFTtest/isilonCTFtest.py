#!/usr/bin/env python
"""Isilon Change File Tracking Performance Test"""

from isilon_api import *
from datetime import datetime, timedelta
import time
import json
import argparse
import os

### command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--isilon', type=str, required=True)
parser.add_argument('-t','--port', default='8080')
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-p', '--path', type=str, default=None)
parser.add_argument('-l', '--listsnapshots', action='store_true')
parser.add_argument('-f', '--firstsnapshot', type=str, default='cohesityCftTestSnap1')
parser.add_argument('-s', '--secondsnapshot', type=str, default='cohesityCftTestSnap2')
parser.add_argument('-d', '--deletethissnapshot', type=str, default=None)
parser.add_argument('-c', '--deletesnapshots', action='store_true')

args = parser.parse_args()

isilon = args.isilon
port = args.port
username = args.username
password = args.password
path = args.path
listsnapshots = args.listsnapshots
firstsnapshot = args.firstsnapshot
secondsnapshot = args.secondsnapshot
deletethissnapshot = args.deletethissnapshot
deletesnapshots = args.deletesnapshots

endpoint = isilon
if ':' not in endpoint:
    endpoint = '%s:%s' % (isilon, port)

isilonauth(endpoint=endpoint, username=username, password=password)


def findSnapshot(snapname):
    if snapshots is not None and 'snapshots' in snapshots and snapshots['snapshots'] is not None:
        thisSnap = [snap for snap in snapshots['snapshots'] if snap['name'].lower() == snapname.lower() or str(snap['id']) == snapname]
        if thisSnap is not None and len(thisSnap) > 0:
            thisSnap = thisSnap[0]
            return thisSnap
    return None


now = datetime.now()

# check licenses
licenses = isilonapi('get', '/platform/1/license/licenses')
license = [lic for lic in licenses['licenses'] if lic['name'] == 'SnapshotIQ']
if license is None or len(license) == 0:
    print('\nThis Isilon is not licensed for SnapshotIQ\n')
    exit()

# check changelistcreate job is enabled and get policy and priority settings
jobTypes = isilonapi('get', '/platform/1/job/types')
jobType = [t for t in jobTypes['types'] if t['id'] == 'ChangelistCreate']
if jobType is None or len(jobType) == 0 or jobType[0]['enabled'] is not True:
    print('Change File Tracking is not enabled on this Isilon')
    exit()
else:
    priority = jobType[0]['priority']
    policy = jobType[0]['policy']

# get list of snapshots
snapshots = isilonapi('get', '/platform/1/snapshot/snapshots')
if path is not None and snapshots is not None and 'snapshots' in snapshots:
    snapshots['snapshots'] = [snap for snap in snapshots['snapshots'] if snap['path'].lower() == path.lower()]

# list snapshots and exit
if listsnapshots:
    if snapshots is not None and 'snapshots' in snapshots and snapshots['snapshots'] is not None:
        print('\nID          Created               Age (hours)   Path               Name')
        print('==          =======               ===========   ====               ====')
        for snapshot in snapshots['snapshots']:
            created = usecsToDateTime(snapshot['created'] * 1000000)
            deltahours = int((now - created).total_seconds() / 3600)
            print('%-9s   %s   %-11s   %-16s   %s' % (snapshot['id'], created, deltahours, snapshot['path'], snapshot['name']))
    print('')
    exit()

# find specified snapshots
initialSnap = findSnapshot(firstsnapshot)
finalSnap = findSnapshot(secondsnapshot)

# delete one snapshot
if deletethissnapshot is not None:
    thisSnap = findSnapshot(deletethissnapshot)
    if thisSnap is not None:
        print('\nDeleting snapshot %s\n' % thisSnap['id'])
        result = isilonapi('delete', '/platform/1/snapshot/snapshots/%s' % thisSnap['id'])
    else:
        print('\nNo matching snapshot found\n')
    exit()

# clean up
if deletesnapshots:
    # delete old snapshots
    print('\nCleaing up old snapshots...\n')
    if(os.path.isfile('cftStore.json') is True):
        os.remove('cftStore.json')
    if initialSnap is not None:
        result = isilonapi('delete', '/platform/1/snapshot/snapshots/%s' % initialSnap['id'])
    if finalSnap is not None:
        result = isilonapi('delete', '/platform/1/snapshot/snapshots/%s' % finalSnap['id'])
    exit()

# avoid using an older second snapshot
if initialSnap is not None and finalSnap is not None:
    if finalSnap['created'] <= initialSnap['created']:
        if finalSnap['name'] == 'cohesityCftTestSnap2':
            result = isilonapi('delete', '/platform/1/snapshot/snapshots/%s' % finalSnap['id'])
            finalSnap = None
        else:
            print('Invalid: second snapshot (%s) is older than the first snapshot (%s)' % (secondsnapshot, firstsnapshot))
            exit()

# create first snapshot
if initialSnap is None:
    if path is None:
        print('\nPath is required\n')
        exit()
    print('\nCreating initial snapshot, please wait for file changes, then re-run the script to calculate CFT performance')
    initialSnap = isilonapi('post', '/platform/1/snapshot/snapshots', {"name": firstsnapshot, "path": path})
    if initialSnap is not None:
        print('New Snap ID: %s\n' % initialSnap['id'])
    if(os.path.isfile('cftStore.json') is True):
        os.remove('cftStore.json')
    exit()

# create second snapshot
if finalSnap is None:
    path = initialSnap['path']
    print('\nCreating second snapshot')
    finalSnap = isilonapi('post', '/platform/1/snapshot/snapshots', {"name": secondsnapshot, "path": path})
    if finalSnap is not None:
        print('New Snap ID: %s' % finalSnap['id'])
    if os.path.isfile('cftStore.json') is True:
        os.remove('cftStore.json')
    if finalSnap is None:
        exit()

# create CFT job
if os.path.isfile('cftStore.json') is False:
    nowMsecs = int(dateToUsecs() / 1000)
    newCFTjob = {
        "allow_dup": False,
        "policy": "LOW",
        "priority": 5,
        "type": "ChangelistCreate",
        "changelistcreate_params": {
            "older_snapid": initialSnap['id'],
            "newer_snapid": finalSnap['id']
        }
    }
    print('\nCreating CFT Test Job')
    job = isilonapi('post', '/platform/1/job/jobs?_dc=%s' % nowMsecs, newCFTjob)
    jobId = job['id']
    startTimeUsecs = dateToUsecs()
    cftStore = open('cftStore.json', 'w')
    cftStore.write(json.dumps({'jobId': jobId, 'startTimeUsecs': startTimeUsecs}, sort_keys=True, indent=4, separators=(', ', ': ')))
    cftStore.close()

# calculate hour different between the two snapshots
initialSnapCreateTime = usecsToDateTime(initialSnap['created'] * 1000000)
finalSnapCreateTime = usecsToDateTime(finalSnap['created'] * 1000000)
deltahours = (finalSnapCreateTime - initialSnapCreateTime).total_seconds() / 3600

# get CFT job status
cftStore = json.loads(open('cftStore.json', 'r').read())
jobId = cftStore['jobId']
startTimeUsecs = cftStore['startTimeUsecs']

reportedWaiting = False

while True:
    reports = isilonapi('get', '/platform/1/job/reports?job_type=ChangelistCreate')
    if reports is not None and len(reports['reports']) > 4:
        reports = [rep for rep in reports['reports'] if rep['job_id'] == jobId]
        if reports is not None and len(reports) >= 4:
            report = reports[0]
            endTimeUsecs = report['time'] * 1000000
            endTime = usecsToDateTime(endTimeUsecs)
            startTime = usecsToDateTime(startTimeUsecs)
            totalseconds = (endTime - startTime).total_seconds()
            totalhours = totalseconds / 3600
            timeSpan = timedelta(seconds=totalseconds)
            timedays = timeSpan.days
            timehours = timeSpan.seconds // 3600
            timeminutes = (timeSpan.seconds // 60) % 60
            timesecs = (timeSpan.seconds) % 60
            duration = '%s:%s:%s:%s' % (timedays, timehours, timeminutes, timesecs)
            print('\nCFT job completion time: %s' % duration)
            estimate24hours = int((24 / deltahours) * totalhours)
            print('Estimated job completion time for daily snapshots: %s hours\n' % estimate24hours)
            exit()
        else:
            if reportedWaiting is False:
                reportedWaiting = True
                print('\nWaiting for CFT job to complete (wait or press CTRL-C to exit and re-run the script later to check status)...')
            time.sleep(15)
    else:
        if reportedWaiting is False:
            reportedWaiting = True
            print('\nWaiting for CFT job to complete (wait or press CTRL-C to exit and re-run the script later to check status)...')
        time.sleep(15)
