#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-n', '--objectname', action='append', type=str)
parser.add_argument('-l', '--objectlist', type=str)
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-f', '--finalbackup', action='store_true')
parser.add_argument('-x', '--unprotect', action='store_true')
parser.add_argument('-z', '--nobackuprequired', action='store_true')
parser.add_argument('-r', '--region', type=str, default=None)

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
objectnames = args.objectname
objectlist = args.objectlist
policyname = args.policyname
finalbackup = args.finalbackup
unprotect = args.unprotect
nobackuprequired = args.nobackuprequired
region = args.region

if not finalbackup and not unprotect:
    print('no actions specified')
    exit()
if finalbackup and unprotect:
    print('only one action may be specified')
    exit()


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


objectnames = gatherList(objectnames, objectlist, name='objects', required=True)

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

if region is not None:
    thisRegion = [r['regionId'] for r in regions['tenantRegionInfoList'] if r['regionId'].lower() == region.lower()]
    if thisRegion is None or len(thisRegion) == 0:
        print('region %s not found' % region)
        exit(1)
    else:
        regionList = thisRegion[0]

if finalbackup and policyname is not None:
    policies = api('get', 'data-protect/policies?types=DMaaSPolicy', mcmv2=True)
    policy = [p for p in policies['policies'] if p['name'].lower() == policyname.lower()]
    if policy is None or len(policy) == 0:
        print('policy %s not found' % policyname)
        exit(1)

for objectname in objectnames:
    search = api('get', 'data-protect/search/objects?searchString=%s&regionIds=%s' % (objectname, regionList), v=2)
    if search is not None and 'objects' in search and search['objects'] is not None and len(search['objects']) > 0:
        matchingObjects = [o for o in search['objects'] if o['name'].lower() == objectname.lower()]
        if matchingObjects is not None and len(matchingObjects) > 0:
            for matchingObject in matchingObjects:
                if 'objectProtectionInfos' in matchingObject and matchingObject['objectProtectionInfos'] is not None and len(matchingObject['objectProtectionInfos']) > 0:
                    for protection in [i for i in matchingObject['objectProtectionInfos'] if i['regionId'] in regionList]:
                        protectedObjects = api('get', 'data-protect/objects?ids=%s&regionIds=%s' % (protection['objectId'], protection['regionId']), v=2, quiet=True)
                        if protectedObjects is not None and 'objects' in protectedObjects and protectedObjects['objects'] is not None and len(protectedObjects['objects']) > 0:
                            for protectedObject in protectedObjects['objects']:
                                if 'objectBackupConfiguration' in protectedObject and protectedObject['objectBackupConfiguration'] is not None:
                                    if finalbackup and policyname is not None:
                                        protectedObject['objectBackupConfiguration']['policyId'] = policy[0]['id']
                                        print(':)  %s (%s): updating policy' % (objectname, protection['regionId']))
                                        updatedObject = api('put', 'data-protect/protected-objects/%s?regionId=%s' % (protection['objectId'], protection['regionId']), protectedObject['objectBackupConfiguration'], v=2)
                                    if finalbackup:
                                        runParams = {
                                            "action": "ProtectNow",
                                            "runNowParams": {
                                                "objects": [
                                                    {
                                                        "id": protectedObject['id'],
                                                        "takeLocalSnapshotOnly": False
                                                    }
                                                ]
                                            }
                                        }
                                        # handle multiple protections
                                        if 'policyConfig' in protectedObject['objectBackupConfiguration']:
                                            thesepolicies = protectedObject['objectBackupConfiguration']['policyConfig']['policies']
                                            if len(policies) > 1:
                                                runParams['snapshotBackendTypes'] = []
                                                for thispolicy in thesepolicies:
                                                    protectionType = thispolicy['protectionType']
                                                    if protectedObject['environment'] == 'kAWS':
                                                        if protectionType == 'kNative':
                                                            protectionType = 'kAWSNative'
                                                        if protectionType == 'kSnapshotManager':
                                                            protectionType = 'kAWSSnapshotManager'
                                                    runParams['snapshotBackendTypes'].append(protectionType)
                                        print(':)  %s (%s): starting backup' % (objectname, protection['regionId']))
                                        runnow = api('post', 'data-protect/protected-objects/actions?regionId=%s' % protection['regionId'], runParams, v=2)
                                    if unprotect:
                                        activityParams = {
                                            "statsParams": {
                                                "attributes": [
                                                    "Status",
                                                    "ActivityType"
                                                ]
                                            },
                                            "fromTimeUsecs": timeAgo(1, 'days'),
                                            "toTimeUsecs": timeAgo(1, 'seconds'),
                                            "objectIdentifiers": [
                                                {
                                                    "objectId": protection['objectId'],
                                                    "clusterId": None,
                                                    "regionId": protection['regionId']
                                                }
                                            ]
                                        }
                                        backupCompleted = False
                                        finishedStates = ['Succeeded', 'Warning']
                                        badStates = ['Canceled', 'Failed']
                                        result = api('post', 'data-protect/objects/activity', activityParams, mcmv2=True)
                                        if result is not None and 'activity' in result and result['activity'] is not None and len(result['activity']) > 0:
                                            if 'archivalRunParams' in result['activity'][0] and result['activity'][0]['archivalRunParams'] is not None and 'status' in result['activity'][0]['archivalRunParams']:
                                                if result['activity'][0]['archivalRunParams'] in badStates:
                                                    print('X   %s (%s): backup status: %s' % (objectname, protection['regionId'], result['activity'][0]['archivalRunParams']['status']))
                                                if result['activity'][0]['archivalRunParams']['status'] in finishedStates:
                                                    backupCompleted = True
                                        if backupCompleted or nobackuprequired:
                                            unprotectParams = {
                                                "action": "UnProtect",
                                                "unProtectParams": {
                                                    "objects": [
                                                        {
                                                            "id": protection['objectId'],
                                                            "deleteAllSnapshots": False,
                                                            "forceUnprotect": True
                                                        }
                                                    ]
                                                }
                                            }
                                            print(':)  %s (%s): unprotecting' % (objectname, protection['regionId']))
                                            unprotect = api('post', 'data-protect/protected-objects/actions?regionId=%s' % protection['regionId'], unprotectParams, v=2)
                                        else:
                                            print('X   %s (%s): waiting for backup to complete' % (objectname, protection['regionId']))
                                else:
                                    print('    %s (%s): not protected' % (objectname, protection['regionId']))
                        else:
                            print('    %s (%s): not protected' % (objectname, protection['regionId']))
                else:
                    print('    %s: not protected' % objectname)
        else:
            print('?   %s: not found' % objectname)
    else:
        print('?   %s: not found' % objectname)
