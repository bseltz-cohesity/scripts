#!/usr/bin/env python
"""Report Protected AWS Objects (EC2/RDS) with AWS Resource Tags - 2026-07-23"""

# Warning: this code is provided on a best effort basis and is not in any way
# officially supported or sanctioned by Cohesity. It is intentionally kept
# simple to retain value as example code. Provided as-is with no warranty.
#
# This script reports on Cohesity-protected AWS objects (EC2 instances and
# RDS databases) and includes each object's AWS resource tags (the tags
# assigned in AWS itself, e.g. Environment=Production, CostCenter=1234).
# Optionally filter the report down to objects that carry a specific tag
# key (and, optionally, a specific value).
#
# It is built from the same data path used by storagePerObjectReport.py in
# this repo (searchvms -> awsEntity.tagAttributesVec), combined with the
# object/job walking pattern used by protectedObjectInventory.py.

from pyhesity import *
from datetime import datetime
import codecs

# command line arguments ######################################################
import argparse
parser = argparse.ArgumentParser()

# authentication params
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
parser.add_argument('-e', '--emailmfacode', action='store_true')

# report params
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
parser.add_argument('-tk', '--tagkey', type=str, default=None, help='only include objects with this AWS tag key')
parser.add_argument('-tv', '--tagvalue', type=str, default=None, help='only include objects where --tagkey equals this value (requires --tagkey)')
parser.add_argument('-o', '--objectname', action='append', type=str, help='only include this object name (repeat for multiple)')
parser.add_argument('-s', '--skipdeleted', action='store_true')
parser.add_argument('-debug', '--debug', action='store_true')

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
emailmfacode = args.emailmfacode
folder = args.outfolder
units = args.units
tagkey = args.tagkey
tagvalue = args.tagvalue
objectnames = [o.lower() for o in args.objectname] if args.objectname else None
skipdeleted = args.skipdeleted
debug = args.debug

if tagvalue is not None and tagkey is None:
    print('-tv, --tagvalue requires -tk, --tagkey to also be specified')
    exit(1)

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

if units.lower() == 'mib':
    units = 'MiB'
    multiplier = 1024 * 1024
else:
    units = 'GiB'
    multiplier = 1024 * 1024 * 1024

scriptVersion = '2026-07-23 (Python)'

now = datetime.now()
datestring = now.strftime("%Y-%m-%d-%H-%M")
csvfileName = '%s/awsProtectedObjectsByTag-%s.csv' % (folder, datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","AWS Source","Protection Group","Policy Name","Object Name","Object Type","Object ID","Front End Size (%s)","Last Backup","Last Status","Last Run Type","Job Paused","AWS Tags"\n' % units)

rowsWritten = 0


def tagListToDict(tagAttributesVec):
    """Convert Cohesity's awsEntity.tagAttributesVec into a {key: value} dict.
    Cohesity packs AWS tags into a single 'name' field formatted as
    'TagKey#~#TagValue'."""
    tags = {}
    for t in tagAttributesVec:
        raw = t.get('name', '')
        if '#~#' in raw:
            k, v = raw.split('#~#', 1)
        else:
            k, v = raw, ''
        tags[k] = v
    return tags


def tagsToDisplayString(tagDict):
    return '; '.join(['%s: %s' % (k, v) for k, v in sorted(tagDict.items())])


def report():
    global rowsWritten

    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])

    if skipdeleted:
        jobs = api('get', 'data-protect/protection-groups?environments=kAWS&isDeleted=false&includeTenants=true', v=2)
    else:
        jobs = api('get', 'data-protect/protection-groups?environments=kAWS&includeTenants=true', v=2)

    if jobs is None or 'protectionGroups' not in jobs or jobs['protectionGroups'] is None:
        print('  no AWS protection groups found')
        return

    awsJobs = [j for j in jobs['protectionGroups'] if j['environment'] == 'kAWS']
    if len(awsJobs) == 0:
        print('  no AWS protection groups found')
        return

    policies = api('get', 'data-protect/policies', v=2)['policies']
    sources = api('get', 'protectionSources/rootNodes')

    for job in sorted(awsJobs, key=lambda j: j['name'].lower()):
        print('  %s' % job['name'])

        v1JobId = job['id'].split(':')[2]

        policy = [p for p in policies if p['id'] == job['policyId']]
        policyName = policy[0]['name'] if len(policy) > 0 else '-'

        # tag/size data per object, via searchvms (same path storagePerObjectReport.py uses)
        objTags = {}
        objSize = {}
        objType = {}
        vmsearch = api('get', '/searchvms?allUnderHierarchy=true&entityTypes=kAWS&jobIds=%s' % v1JobId, quiet=True)
        if vmsearch is not None and 'vms' in vmsearch and vmsearch['vms'] is not None:
            for vm in vmsearch['vms']:
                try:
                    entity = vm['vmDocument']['objectId']['entity']
                    objId = entity['id']
                    awsEntity = entity.get('awsEntity', {})
                    tagVec = awsEntity.get('tagAttributesVec', None)
                    if tagVec is not None and len(tagVec) > 0:
                        objTags[objId] = tagListToDict(tagVec)
                    if objId not in objSize:
                        try:
                            objSize[objId] = entity['sizeInfo'][0]['value']['sourceDataSizeBytes']
                        except Exception:
                            objSize[objId] = 0
                    objType[objId] = awsEntity.get('type', entity.get('type', ''))
                except Exception:
                    continue

        # latest run for status / per-object details
        runs = api('get', 'data-protect/protection-groups/%s/runs?includeObjectDetails=true&numRuns=1' % job['id'], v=2, quiet=True)
        if runs is None or 'runs' not in runs or runs['runs'] is None or len(runs['runs']) == 0:
            continue

        run = runs['runs'][0]
        runInfo = run.get('localBackupInfo', None) or (run.get('archivalInfo', {}).get('archivalTargetResults', [{}])[0])
        lastRunType = runInfo.get('runType', '-')
        if isinstance(lastRunType, str) and lastRunType.startswith('k'):
            lastRunType = lastRunType[1:]

        for item in run.get('objects', []):
            obj = item['object']
            objId = obj['id']
            objName = obj['name']

            if objectnames is not None and objName.lower() not in objectnames:
                continue

            tags = objTags.get(objId, {})

            # tag filter
            if tagkey is not None:
                if tagkey not in tags:
                    continue
                if tagvalue is not None and tags.get(tagkey) != tagvalue:
                    continue

            if 'localSnapshotInfo' in item:
                info = item['localSnapshotInfo']['snapshotInfo']
                lastStatus = info['status']
            elif 'archivalInfo' in item:
                info = item['archivalInfo']['archivalTargetResults'][0]
                lastStatus = info['status']
            else:
                info = {}
                lastStatus = '-'
            if isinstance(lastStatus, str) and lastStatus.startswith('k'):
                lastStatus = lastStatus[1:]

            lastBackupUsecs = info.get('startTimeUsecs', None)
            lastBackup = usecsToDate(lastBackupUsecs) if lastBackupUsecs else '-'

            sizeBytes = objSize.get(objId, 0)
            if sizeBytes == 0:
                try:
                    sizeBytes = info['stats']['logicalSizeBytes']
                except Exception:
                    sizeBytes = 0
            sizeDisplay = round(sizeBytes / multiplier, 2)

            thisObjType = objType.get(objId, obj.get('objectType', '-'))
            if isinstance(thisObjType, str) and thisObjType.startswith('k'):
                thisObjType = thisObjType[1:]

            tagDisplay = tagsToDisplayString(tags)

            # source (parent/account) name lookup, per-object
            sourceName = '-'
            objSourceId = obj.get('sourceId', None)
            if objSourceId is not None:
                parent = [s for s in sources if s['protectionSource']['id'] == objSourceId]
                if len(parent) > 0:
                    sourceName = parent[0]['protectionSource']['name']

            csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (
                cluster['name'],
                sourceName,
                job['name'],
                policyName,
                objName,
                thisObjType,
                objId,
                sizeDisplay,
                lastBackup,
                lastStatus,
                lastRunType,
                job.get('isPaused', False),
                tagDisplay
            ))
            rowsWritten += 1


for vip in vips:

    # authentication ==========================================================
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey,
            helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode,
            tenantId=tenant, quiet=True)

    if apiconnected() is False:
        print('authentication failed for %s' % vip)
        continue

    if mcm or vip.lower() == 'helios.cohesity.com':
        if clusternames is None or len(clusternames) == 0:
            clusternames = [c['name'] for c in heliosClusters()]
        for clustername in clusternames:
            heliosCluster(clustername)
            if LAST_API_ERROR() != 'OK':
                continue
            report()
    else:
        report()
    # end authentication ======================================================

csv.close()
print('\n%s rows written' % rowsWritten)
print('Output saved to %s\n' % csvfileName)
