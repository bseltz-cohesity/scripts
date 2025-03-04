#!/usr/bin/env python

from pyhesity import *
from time import sleep
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-o', '--objectname', type=str, default=None)
parser.add_argument('-s', '--sourcename', type=str, default=None)
parser.add_argument('-r', '--region', type=str, default=None)
parser.add_argument('-e', '--environment', type=str, default=None)
parser.add_argument('-t', '--subtype', type=str, default=None)

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
objectname = args.objectname
sourcename = args.sourcename
region = args.region
environment = args.environment
subtype = args.subtype

# authentication =========================================================
apiauth(username=username, password=password, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

# gather helios tenant info
sessionUser = api('get', 'sessionUser')
tenantId = sessionUser['profiles'][0]['tenantId']
regions = api('get', 'dms/tenants/regions?tenantId=%s' % tenantId, mcmv2=True)
regionList = ','.join([r['regionId'] for r in regions['tenantRegionInfoList']])

activityQuery = {
    "statsParams": {
        "attributes": [
            "Status",
            "ActivityType"
        ]
    },
    "statuses": [
        "Running",
        "Accepted"
    ],
    "activityTypes": [
        "ArchivalRun",
        "BackupRun"
    ]
}

if environment is not None:
    activityQuery['environments'] = [environment]

if subtype is not None:
    activityQuery['archivalRunParams'] = {"protectionEnvironmentTypes": [subtype]}

if region is not None:
    activities = api('post', 'data-protect/objects/activity?regionIds=%s' % region, activityQuery, mcmv2=True)
else:
    activities = api('post', 'data-protect/objects/activity?regionIds=%s' % regionList, activityQuery, mcmv2=True)

activities = [a for a in activities['activity'] if a['archivalRunParams']['status'] in ['Running', 'Accepted']]
if activities is None or len(activities) == 0:
    print("No active backups")
    exit(0)

if sourcename is not None:
    activities = [a for a in activities if a['object']['sourceName'].lower() == sourcename.lower()]
    if activities is None or len(activities) == 0:
        print("No active backups for %s" % sourcename)
        exit(0)

if objectname is not None:
    activities = [a for a in activities if a['object']['name'].lower() == objectname.lower()]
    if activities is None or len(activities) == 0:
        print("No active backups for %s" % objectname)
        exit(0)

foundactive = 0
for activity in [a for a in activities if 'endTimeUsecs' not in a]:
    if 'endTimeUsecs' not in activity['archivalRunParams']:
        if subtype is None or activity['archivalRunParams']['protectionEnvironmentType'].lower() == subtype.lower():
            print('Cancelling backup for %s' % activity['object']['name'])
            cancel = api('post', 'data-protect/objects/runs/cancel?regionIds=%s' % activity['regionId'], {"objectRuns": [{"objectId": activity['object']['id']}]}, v=2)
            foundactive += 1
if foundactive == 0:
    print('No active backups found')
    exit(0)
