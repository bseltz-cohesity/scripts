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
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-a', '--abortifrunning', action='store_true')
parser.add_argument('-z', '--sleeptime', type=int, default=60)
parser.add_argument('-t', '--backuptype', type=str, choices=['kLog', 'kRegular', 'kFull'], default='kRegular')

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
objectname = args.objectname
sourcename = args.sourcename
region = args.region
wait = args.wait
abortifrunning = args.abortifrunning
sleeptime = args.sleeptime
backuptype = args.backuptype

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

nowUsecs = dateToUsecs()
tomorrowUsecs = nowUsecs + 86400000000
weekAgoUsecs = timeAgo(1, 'day')

runParams = {
    "action": "ProtectNow",
    "runNowParams": {
        "objects": []
    }
}

if objectname is not None:
    if region is not None:
        objects = api('get', 'data-protect/search/objects?searchString=%s&includeTenants=true&regionIds=%s' % (objectname, region), v=2)
    else:
        objects = api('get', 'data-protect/search/objects?searchString=%s&includeTenants=true&regionIds=%s' % (objectname, regionList), v=2)
    objects = [o for o in objects['objects'] if o['name'].lower() == objectname.lower()]
    if sourcename is not None:
        objects = [o for o in objects if o['sourceInfo']['name'].lower() == sourcename.lower()]
    if len(objects) == 0:
        print('%s not found' % objectname)
        exit(1)
    for obj in objects:
        for objectProtectionInfo in [o for o in obj['objectProtectionInfos'] if o['objectBackupConfiguration'] is not None]:
            protectedObjectId = objectProtectionInfo['objectId']
            runParams['runNowParams']['objects'].append({
                "id": protectedObjectId,
                "takeLocalSnapshotOnly": False,
                "backupType": backuptype
            })
            regionId = objectProtectionInfo['regionId']
            object = api('get', 'data-protect/objects?ids=%s&regionId=%s' % (protectedObjectId, regionId), v=2)
            break
elif sourcename is not None:
    if region is not None:
        sources = api('get', 'data-protect/sources?regionIds=%s' % region, mcmv2=True)
    else:
        sources = api('get', 'data-protect/sources?regionIds=%s' % regionList, mcmv2=True)
    source = [s for s in sources['sources'] if s['name'].lower() == sourcename.lower()]
    if len(source) == 0:
        print('%s not found' % sourcename)
        exit(1)
    source = source[0]
    regionId = source['sourceInfoList'][0]['regionId']
    protectedObjects = api('get', 'data-protect/objects?parentId=%s&onlyProtectedObjects=true&onlyAutoProtectedObjects=false&regionId=%s' % (source['sourceInfoList'][0]['sourceId'], regionId), v=2)
    protectedObjects = [o for o in protectedObjects['objects'] if o['name'].lower() == sourcename.lower()]
    if len(protectedObjects) == 0:
        print('%s is not protected' % sourcename)
        exit(1)
    for obj in protectedObjects:
        runParams['runNowParams']['objects'].append({
            "id": obj['id'],
            "takeLocalSnapshotOnly": False,
            "backupType": backuptype
        })
        object = api('get', 'data-protect/objects?ids=%s&regionId=%s' % (obj['id'], regionId), v=2)
        break
else:
    print("--objectname or --sourcename required")
    exit()

# handle multiple protections
# display(object['objects'])
# policies = object['objects'][0]['objectBackupConfiguration']['policyConfig']['policies']
# if len(policies) > 1:
#     runParams['snapshotBackendTypes'] = []
#     for protectionType in policies['protectionType']:
#         if object['objects'][0]['environment'] == 'kAWS':
#             if protectionType == 'kNative':
#                 protectionType = 'kAWSNative'
#             if protectionType == 'kSnapshotManager':
#                 protectionType = 'kAWSSnapshotManager'
#         runParams['snapshotBackendTypes'].append(protectionType)

activityParams = {
    "statsParams": {
        "attributes": [
            "Status",
            "ActivityType"
        ]
    },
    "activityTypes": [
        "ArchivalRun",
        "BackupRun"
    ],
    "fromTimeUsecs": weekAgoUsecs,
    "toTimeUsecs": tomorrowUsecs
}

# wait for existing run to finish
finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']
allFinished = False
reportWaiting = True
while allFinished is False:
    allFinished = True
    result = api('post', 'data-protect/objects/activity?regionId=%s' % regionId, activityParams, mcmv2=True)
    if 'activity' in result and result['activity'] is not None and len(result['activity']) > 0:
        for protectedObject in runParams['runNowParams']['objects']:
            protectedObjectId = protectedObject['id']
            activities = [a for a in result['activity'] if a['object']['id'] == protectedObjectId or a['sourceInfo']['id'] == protectedObjectId]
            for act in activities:
                if 'archivalRunParams' in act and 'status' in act['archivalRunParams']:
                    status = act['archivalRunParams']['status']
                    if status not in finishedStates:
                        if abortifrunning is True:
                            print('Backup already in progress')
                            exit(1)
                        allFinished = False
                        if reportWaiting is True:
                            print('Waiting for existing run to finish')
                            reportWaiting = False
        if allFinished is True:
            break
        sleep(sleeptime)
    else:
        allFinished = False

result = api('post', 'data-protect/protected-objects/actions?regionId=%s' % regionId, runParams, v=2)

if result is not None and 'objects' in result and result['objects'] is not None and len(result['objects']) > 0:
    if 'runNowStatus' in result['objects'][0] and 'error' in result['objects'][0]['runNowStatus']:
        error = result['objects'][0]['runNowStatus']['error']
        if 'message' in error:
            print(error['message'])
    else:
        if objectname is not None:
            print('Running backup of %s' % objectname)
        else:
            print('Running backup of %s' % sourcename)

        if wait is True:
            sleep(sleeptime)
            activityParams['fromTimeUsecs'] = nowUsecs
            status = 'unknown'
            allFinished = False
            worstStatus = 'Succeeded'
            while allFinished == False:
                allFinished = True
                result = api('post', 'data-protect/objects/activity?regionId=%s' % regionId, activityParams, mcmv2=True)
                if 'activity' in result and result['activity'] is not None and len(result['activity']) > 0:
                    for protectedObject in runParams['runNowParams']['objects']:
                        protectedObjectId = protectedObject['id']
                        activities = [a for a in result['activity'] if a['object']['id'] == protectedObjectId or a['sourceInfo']['id'] == protectedObjectId]
                        for act in activities:
                            if 'archivalRunParams' in act and 'status' in act['archivalRunParams']:
                                status = act['archivalRunParams']['status']
                                if status == 'Failed':
                                    worstStatus = 'Failed'
                                if worstStatus != 'Failed' and status == 'Canceled':
                                    worstStatus = 'Cenceled'
                                if worstStatus != 'Failed' and worstStatus != 'Canceled' and status == 'SucceededWithWarning':
                                    worstStatus = 'SucceededWithWarning'
                                if status not in finishedStates:
                                    allFinished = False
                    if allFinished is True:
                        break
                    sleep(sleeptime)
                else:
                    allFinished = False
            print('Backup finished with status: %s' % worstStatus)
else:
    print('An unknown error occured')
    exit(1)
exit(0)
