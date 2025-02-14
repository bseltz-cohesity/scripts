#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
import codecs
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-y', '--daysback', type=int, default=7)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-f', '--outfilename', type=str, default='recoveryStatsReport.csv')
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
folder = args.outfolder
daysback = args.daysback
outfilename = args.outfilename
units = args.units

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

now = datetime.now()
nowusecs = dateToUsecs()
midnight = datetime.combine(now, datetime.min.time())
midnightusecs = dateToUsecs(midnight)
tonightusecs = midnightusecs + 86399000000
tonightMsecs = int(round(midnightusecs + 86400000000) / 1000)
beforeusecs = midnightusecs - (daysback * 86400000000) + 86400000000

# outfile
outfilename = '%s/%s' % (folder, outfilename)
f = codecs.open(outfilename, 'w')
f.write('"Cluster","Recovery Task Name","Recovery Task ID","Recovery Task Start Time","Recovery Task End Time","Duration (Sec)","Recovery Type","Object Name","Logical Size (%s)","Front End Size (%s)","Data Transferred (%s)","Status","Username"\n' % (units, units, units))

def reportCluster():
    cluster = api('get', 'cluster')
    recoveries = api('get', 'data-protect/recoveries?startTimeUsecs=%s&includeTenants=true&endTimeUsecs=%s' % (beforeusecs, tonightusecs), v=2)
    if recoveries is None or 'recoveries' not in recoveries or recoveries['recoveries'] is None or len(recoveries['recoveries']) == 0:
        return None

    statsEntities = api('get', 'statistics/entities?maxEntities=1000&schemaName=kMagnetoRestoreTaskStats&metricName=kNumBytesWritten')

    logicalSizes = {}
    frontEndSizes = {}

    for recovery in recoveries['recoveries']:
        thisRecovery = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
        if 'endTimeUsecs' not in thisRecovery:
            continue
        print('%s: %s (%s)' %(cluster['name'], thisRecovery['name'], thisRecovery['recoveryAction']))
        recoveryUser = thisRecovery['creationInfo']['userName']
        recoveryStart = usecsToDate(thisRecovery['startTimeUsecs'])
        recoveryEnd = usecsToDate(thisRecovery['endTimeUsecs'])
        duration = (int(round(((thisRecovery['endTimeUsecs'] - thisRecovery['startTimeUsecs']) / 1000000))))
        recoveryId = thisRecovery['id']
        v1TaskId = int(recoveryId.split(':')[-1])
        statsEntity = [e for e in statsEntities if e['entityId']['entityId']['data']['int64Value'] == v1TaskId]
        if statsEntity is not None and len(statsEntity) > 0:
            statsEntity = statsEntity[0]
        else:
            statsEntity = None
        # find environment params
        paramskeys = [k for k in thisRecovery.keys() if k.endswith('Params')]
        if paramskeys is not None and len(paramskeys) > 0:
            paramskey = paramskeys[0]
        else:
            continue
        params = thisRecovery[paramskey]
        for object in params['objects']:
            objectName = object['objectInfo']['name']
            if 'status' in object:
                objectStatus = object['status']
            else:
                objectStatus = thisRecovery['status']
            objectId = object['objectInfo']['id']
            logicalSize = 0
            frontEndSize = 0
            # get logical size
            if objectId not in logicalSizes.keys():
                search = api('get','/searchvms?entityIds=%s' % objectId)
                if search is not None and 'vms' in search and len(search['vms']) > 0:
                    logicalSize = search['vms'][0]['vmDocument']['versions'][0]['logicalSizeBytes']
                    entityProps = [p for p in search['vms'][0]['vmDocument']['objectId']['entity'].keys() if p.endswith('Entity')]
                    if entityProps is not None and len(entityProps) > 0:
                        entityProp = entityProps[0]
                        entity = search['vms'][0]['vmDocument']['objectId']['entity'][entityProp]
                        if 'frontEndSizeInfo' in entity and entity['frontEndSizeInfo'] is not None and 'sizeBytes' in entity['frontEndSizeInfo'] and entity['frontEndSizeInfo']['sizeBytes'] is not None:
                            if entity['frontEndSizeInfo']['sizeBytes'] > 0:
                                frontEndSize = entity['frontEndSizeInfo']['sizeBytes']
                logicalSizes[objectId] = logicalSize
                if frontEndSize == 0 and logicalSize > 0:
                    frontEndSize = logicalSize
                if frontEndSize > logicalSize:
                    frontEndSize = logicalSize
                frontEndSizes[objectId] = frontEndSize
            else:
                logicalSize = logicalSizes[objectId]
                frontEndSize = frontEndSizes[objectId]
            totalTransferred = 0
            if statsEntity is not None:
                startDate = usecsToDateTime(thisRecovery['startTimeUsecs'])
                morning = datetime.combine(startDate, datetime.min.time())
                morningMsecs = int(round(dateToUsecs(morning) / 1000))
                stats = api('get','statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kNumBytesWritten&metricUnitType=0&range=month&rollupFunction=average&rollupIntervalSecs=180&schemaName=kMagnetoRestoreTaskStats&startTimeMsecs=%s' % (tonightMsecs, v1TaskId, morningMsecs))
                if stats is not None and 'dataPointVec' in stats:
                    for dataPoint in stats['dataPointVec']:
                        totalTransferred += dataPoint['data']['int64Value']
            else:
                if totalTransferred == 0:
                    totalTransferred = frontEndSize
            if objectStatus == 'Failed':
                totalTransferred = 0
            totalTransferred = round(totalTransferred / multiplier, 1)
            frontEndSize = round(frontEndSize / multiplier, 1)
            logicalSize = round(logicalSize / multiplier, 1)
            f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], thisRecovery['name'], thisRecovery['id'], recoveryStart, recoveryEnd, duration, thisRecovery['recoveryAction'], objectName, logicalSize, frontEndSize, totalTransferred, objectStatus, recoveryUser))

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
            reportCluster()
    else:
        reportCluster()

f.close()
print('\nOutput saved to %s\n' % outfilename)

