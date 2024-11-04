#!/usr/bin/env python
"""Storage Per Object Report version 2024.10.23 for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
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
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-y', '--growthdays', type=int, default=7)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
parser.add_argument('-s', '--skipdeleted', action='store_true')
parser.add_argument('-a', '--includearchives', action='store_true')
parser.add_argument('-debug', '--debug', action='store_true')
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
numruns = args.numruns
growthdays = args.growthdays
units = args.units
skipdeleted = args.skipdeleted
debug = args.debug
includearchives = args.includearchives

scriptVersion = '2024-10-23 (Python)'

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
midnight = datetime.combine(now, datetime.min.time())
midnightusecs = dateToUsecs(midnight)
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
growthdaysusecs = timeAgo(growthdays, 'days')
msecsBeforeCurrentTimeToCompare = growthdays * 24 * 60 * 60 * 1000
datestring = now.strftime("%Y-%m-%d-%H-%M")
csvfileName = '%s/storagePerObjectReport-%s.csv' % (folder, datestring)
clusterStatsFileName = '%s/storagePerObjectReport-%s-clusterstats.csv' % (folder, datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
clusterStats = codecs.open(clusterStatsFileName, 'w', 'utf-8')
csv.write('"Cluster Name","Origin","Stats Age (Days)","Protection Group","Tenant","Storage Domain ID","Storage Domain Name","Environment","Source Name","Object Name","Front End Allocated %s","Front End Used %s","%s Stored (Before Reduction)","%s Stored (After Reduction)","%s Stored (After Reduction and Resiliency)","Reduction Ratio","%s Change Last %s Days (After Reduction and Resiliency)","Snapshots","Log Backups","Oldest Backup","Newest Backup","Newest DataLock Expiry","Archive Count","Oldest Archive","%s Archived","%s per Archive Target","Description","VM Tags"\n' % (units, units, units, units, units, units, growthdays, units, units))
clusterStats.write('"Cluster Name","Total Used %s","BookKeeper Used %s","Total Unaccounted Usage %s","Total Unaccounted Percent","Garbage %s","Garbage Percent","Other Unaccounted Usage %s","Other Unaccounted Percent","Reduction Ratio","All Objects Front End Size %s","All Objects Stored (After Reduction) %s","All Objects Stored (After Reduction and Resiliency) %s","Storage Variance Factor","Script Version","Cluster Software Version"\n' % (units, units, units, units, units, units, units, units))


def getCloudStats(cluster):
    vaults = api('get', 'vaults?includeFortKnoxVault=true')
    cloudStats = None
    if vaults is not None and len(vaults) > 0 and includearchives is True:
        nowMsecs = int((dateToUsecs()) / 1000)
        cloudStart = cluster['createdTimeMsecs']
        cloudStatURL = 'reports/dataTransferToVaults?endTimeMsecs=%s&startTimeMsecs=%s' % (nowMsecs, cloudStart)
        for vault in vaults:
            cloudStatURL += '&vaultIds=%s' % vault['id']
        cloudStats = api('get', cloudStatURL)
    return cloudStats


def getConsumerStats(consumerType, msecsBeforeCurrentTimeToCompare):
    cookie = ''
    consumerStats = {'statsList': []}
    while True:
        theseStats = api('get', 'stats/consumers?consumerType=%s&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (consumerType, msecsBeforeCurrentTimeToCompare, cookie))
        if 'statsList' in theseStats:
            consumerStats['statsList'] = consumerStats['statsList'] + theseStats['statsList']
        if 'cookie' in theseStats:
            cookie = theseStats['cookie']
        else:
            cookie = ''
        if cookie == '':
            break
    return consumerStats


def reportStorage():
    sumObjectsUsed = 0
    sumObjectsWritten = 0
    sumObjectsWrittenWithResiliency = 0
    viewHistory = {}
    cluster = api('get', 'cluster?fetchStats=true')
    print('\n%s' % cluster['name'])
    try:
        clusterReduction = round(cluster['stats']['usagePerfStats']['dataInBytes'] / cluster['stats']['usagePerfStats']['dataInBytesAfterReduction'], 1)
        clusterUsed = round(cluster['stats']['usagePerfStats']['totalPhysicalUsageBytes'] / multiplier, 1)
    except Exception:
        clusterReduction = 1
        clusterUsed = 0
    vaults = api('get', 'vaults?includeFortKnoxVault=true')
    cloudStats = None
    if includearchives is True:
        cloudStats = getCloudStats(cluster)
    if skipdeleted:
        jobs = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true&useCachedData=true&onlyReturnBasicSummary=true', v=2)
    else:
        jobs = api('get', 'data-protect/protection-groups?includeTenants=true&useCachedData=true&onlyReturnBasicSummary=true', v=2)

    storageDomains = api('get', 'viewBoxes')

    sourceNames = {}
    localStats = getConsumerStats('kProtectionRuns', growthdays)
    replicaStats = getConsumerStats('kReplicationRuns', growthdays)
    viewRunStats = getConsumerStats('kViewProtectionRuns', growthdays)

    viewJobAltStats = {}

    for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
        v1JobId = job['id'].split(':')[2]
        statsAge = '-'
        jobDescription = ''
        if 'description' in job:
            jobDescription = job['description']
        origin = 'local'
        if job['isActive'] is not True:
            origin = 'replica'
        if job['environment'] not in ['kView']:
            tenant = ''
            if 'permissions' in job and len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
                tenant = job['permissions'][0]['name']
            # get resiliency factor
            resiliencyFactor = 1
            sdname = 'DirectArchive'
            if 'storageDomainId' in job:
                sdid = job['storageDomainId']
                sd = [v for v in storageDomains if v['id'] == job['storageDomainId']]
                if sd is not None and len(sd) > 0:
                    sdname = sd[0]['name']
                    if 'erasureCodingInfo' in sd[0]['storagePolicy']:
                        r = sd[0]['storagePolicy']['erasureCodingInfo']
                        resiliencyFactor = float(r['numDataStripes'] + r['numCodedStripes']) / r['numDataStripes']
                    else:
                        if sd[0]['storagePolicy']['numFailuresTolerated'] == 0:
                            resiliencyFactor = 1
                        else:
                            resiliencyFactor = 2
            objects = {}
            print('  %s' % job['name'])

            jobObjGrowth = 0
            jobGrowth = 0
            # get jobReduction factor
            if job['isActive'] is True:
                stats = localStats
            else:
                stats = replicaStats
            if 'statsList' in stats and stats['statsList'] is not None:
                thisStat = [s for s in stats['statsList'] if s['id'] == int(v1JobId) or s['name'].lower() == job['name'].lower()]
            if 'statsList' in stats and stats['statsList'] is not None and thisStat is not None and len(thisStat) > 0:
                statsTimeUsecs = thisStat[0]['stats'].get('dataWrittenBytesTimestampUsec', 0)
                if statsTimeUsecs > 0:
                    statsAge = round((nowUsecs - statsTimeUsecs) / 86400000000, 0)
                else:
                    statsAge = '-'
                dataIn = thisStat[0]['stats'].get('dataInBytes', 0)
                dataInAfterDedup = thisStat[0]['stats'].get('dataInBytesAfterDedup', 0)
                jobWritten = thisStat[0]['stats'].get('dataWrittenBytes', 0)
                storageConsumedBytes = thisStat[0]['stats'].get('storageConsumedBytes', 0)
                storageConsumedBytesPrev = thisStat[0]['stats'].get('storageConsumedBytesPrev', 0)
                if storageConsumedBytes > 0 and storageConsumedBytesPrev > 0 and resiliencyFactor > 0:
                    jobGrowth = (storageConsumedBytes - storageConsumedBytesPrev) / resiliencyFactor
                if dataInAfterDedup > 0 and jobWritten > 0:
                    dedup = round(float(dataIn) / dataInAfterDedup, 1)
                    compression = round(float(dataInAfterDedup) / jobWritten, 1)
                    jobReduction = round((float(dataIn) / dataInAfterDedup) * (float(dataInAfterDedup) / jobWritten), 1)
                else:
                    jobReduction = 1
            else:
                jobWritten = 0
                dataIn = 0
                jobReduction = clusterReduction
            if jobReduction == 0:
                jobReduction = 1

            if job['environment'] in ['kVMware', 'kAD'] or (job['environment'] == 'kPhysical' and job['physicalParams']['protectionType'] == 'kVolume'):
                if job['environment'] == 'kAD':
                    entityType = 'kPhysical'
                else:
                    entityType = job['environment']
                vmsearch = api('get', '/searchvms?allUnderHierarchy=true&entityTypes=%s&jobIds=%s' % (entityType, v1JobId))
            archiveCount = 0
            oldestArchive = '-'
            lastDataLock = '-'
            endUsecs = nowUsecs
            lastRunId = '0'
            while 1:
                if debug is True:
                    print('    getting protection runs')
                runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true' % (job['id'], numruns, endUsecs), v=2)
                if lastRunId != '0':
                    runs['runs'] = [r for r in runs['runs'] if r['id'] < lastRunId]
                for run in runs['runs']:
                    if 'isLocalSnapshotsDeleted' not in run:
                        # per object stats
                        if 'objects' in run and run['objects'] is not None and len(run['objects']) > 0:
                            for object in [o for o in run['objects'] if o['object']['environment'] != job['environment']]:
                                sourceNames[object['object']['id']] = object['object']['name']
                            for object in [o for o in run['objects']]:
                                objId = object['object']['id']
                                archivalInfo = None
                                runInfo = None
                                if 'localSnapshotInfo' in object:
                                    snap = object['localSnapshotInfo']
                                    runType = run['localBackupInfo']['runType']
                                    runInfo = run['localBackupInfo']
                                elif 'originalBackupInfo' in object:
                                    snap = object['originalBackupInfo']
                                    runType = run['originalBackupInfo']['runType']
                                    runInfo = run['originalBackupInfo']
                                else:
                                    # CAD
                                    snap = None
                                    if 'archivalInfo' in object:
                                        try:
                                            archivalInfo = object['archivalInfo']['archivalTargetResults'][0]
                                            runInfo = run['archivalInfo']['archivalTargetResults'][0]
                                        except Exception:
                                            archivalInfo = None
                                if runInfo is not None and lastDataLock == '-' and 'dataLockConstraints' in runInfo and 'expiryTimeUsecs' in runInfo['dataLockConstraints'] and runInfo['dataLockConstraints']['expiryTimeUsecs'] > 0:
                                    if runInfo['dataLockConstraints']['expiryTimeUsecs'] > nowUsecs:
                                        lastDataLock = usecsToDate(runInfo['dataLockConstraints']['expiryTimeUsecs'])
                                try:
                                    if objId not in objects and not (job['environment'] == 'kAD' and object['object']['environment'] == 'kAD') and not (job['environment'] in ['kSQL', 'kOracle', 'kExchange'] and object['object']['objectType'] == 'kHost'):
                                        objects[objId] = {}
                                        objects[objId]['name'] = object['object']['name']
                                        objects[objId]['logical'] = 0
                                        objects[objId]['alloc'] = 0
                                        objects[objId]['fetb'] = 0
                                        objects[objId]['archiveLogical'] = 0
                                        objects[objId]['bytesRead'] = 0
                                        objects[objId]['archiveBytesRead'] = 0
                                        objects[objId]['growth'] = 0
                                        objects[objId]['numSnaps'] = 0
                                        objects[objId]['numLogs'] = 0
                                        objects[objId]['vmTags'] = ''
                                        objects[objId]['lastDataLock'] = lastDataLock
                                        if 'sourceId' in object['object']:
                                            objects[objId]['sourceId'] = object['object']['sourceId']
                                        if snap is not None:
                                            objects[objId]['newestBackup'] = snap['snapshotInfo']['startTimeUsecs']
                                            objects[objId]['oldestBackup'] = snap['snapshotInfo']['startTimeUsecs']
                                            if 'logicalSizeBytes' not in snap['snapshotInfo']['stats']:
                                                if debug is True:
                                                    print('   looking up source ID')
                                                csource = api('get', 'protectionSources?id=%s&useCachedData=true' % objId, quiet=True)
                                                try:
                                                    if type(csource) is list:
                                                        objects[objId]['logical'] = csource[0]['protectedSourcesSummary'][0]['totalLogicalSize']
                                                        objects[objId]['alloc'] = csource[0]['protectedSourcesSummary'][0]['totalLogicalSize']
                                                    else:
                                                        objects[objId]['logical'] = csource['protectedSourcesSummary'][0]['totalLogicalSize']
                                                        objects[objId]['alloc'] = csource['protectedSourcesSummary'][0]['totalLogicalSize']
                                                except Exception:
                                                    pass
                                            else:
                                                objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                                objects[objId]['alloc'] = snap['snapshotInfo']['stats']['logicalSizeBytes']

                                        if archivalInfo is not None:
                                            objects[objId]['newestBackup'] = archivalInfo['startTimeUsecs']
                                            objects[objId]['oldestBackup'] = archivalInfo['startTimeUsecs']
                                    if objId in objects:
                                        if snap is None and 'logicalSizeBytes' in archivalInfo['stats'] and archivalInfo['stats']['logicalSizeBytes'] > objects[objId]['archiveLogical']:
                                            objects[objId]['archiveLogical'] = archivalInfo['stats']['logicalSizeBytes']
                                        if objects[objId]['fetb'] == 0 and (job['environment'] in ['kVMware', 'kAD'] or (job['environment'] == 'kPhysical' and job['physicalParams']['protectionType'] == 'kVolume')):
                                            if vmsearch is not None and 'vms' in vmsearch and vmsearch['vms'] is not None and len(vmsearch['vms']) > 0:
                                                vms = [vm for vm in vmsearch['vms'] if vm['vmDocument']['objectName'].lower() == object['object']['name'].lower()]
                                                if len(vms) > 0:
                                                    if job['environment'] == 'kVMware':
                                                        vmbytes = vms[0]['vmDocument']['objectId']['entity']['vmwareEntity']['frontEndSizeInfo']['sizeBytes']
                                                        tagAttrs = [a for a in vms[0]['vmDocument']['attributeMap'] if 'VMware_tag' in a['xKey']]
                                                        if tagAttrs is not None and len(tagAttrs) > 0:
                                                            objects[objId]['vmTags'] = ';'.join([a['xValue'] for a in tagAttrs])
                                                    else:
                                                        vmbytes = vms[0]['vmDocument']['objectId']['entity']['sizeInfo'][0]['value']['sourceDataSizeBytes']
                                                    objects[objId]['logical'] = vmbytes
                                                    objects[objId]['fetb'] = vmbytes

                                        if snap is not None and 'logicalSizeBytes' in snap['snapshotInfo']['stats'] and snap['snapshotInfo']['stats']['logicalSizeBytes'] > objects[objId]['logical']:
                                            if objects[objId]['logical'] == 0 or (job['environment'] not in ['kVMware', 'kAD'] and job['environment'] != 'kPhysical' and job['physicalParams']['protectionType'] != 'kVolume'):
                                                objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                        if snap is not None and job['environment'] == 'kVMware' and snap['snapshotInfo']['stats']['logicalSizeBytes'] < objects[objId]['logical'] and snap['snapshotInfo']['stats']['logicalSizeBytes'] > 0:
                                            objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                        if snap is not None:
                                            objects[objId]['bytesRead'] += snap['snapshotInfo']['stats']['bytesRead']
                                            objects[objId]['lastDataLock'] = lastDataLock
                                        if snap is not None and snap['snapshotInfo']['startTimeUsecs'] > growthdaysusecs:
                                            objects[objId]['growth'] += snap['snapshotInfo']['stats']['bytesRead']
                                            jobObjGrowth += snap['snapshotInfo']['stats']['bytesRead']
                                        if runType == 'kLog':
                                            objects[objId]['numLogs'] += 1
                                        else:
                                            objects[objId]['numSnaps'] += 1
                                        if snap is not None:
                                            objects[objId]['oldestBackup'] = snap['snapshotInfo']['startTimeUsecs']
                                        if archivalInfo is not None:
                                            objects[objId]['oldestBackup'] = archivalInfo['startTimeUsecs']
                                            objects[objId]['archiveBytesRead'] += archivalInfo['stats']['bytesRead']

                                except Exception as e:
                                    pass
                    if 'archivalInfo' in run and run['archivalInfo'] is not None and 'archivalTargetResults' in run['archivalInfo'] and run['archivalInfo']['archivalTargetResults'] is not None and len(run['archivalInfo']['archivalTargetResults']) > 0:
                        for archiveResult in run['archivalInfo']['archivalTargetResults']:
                            if 'status' in archiveResult and archiveResult['status'] == 'Succeeded':
                                archiveCount += 1
                                oldestArchive = usecsToDate(run['id'].split(':')[-1])
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

            # process output
            jobFESize = 0
            for object in sorted(objects.keys()):
                thisObject = objects[object]
                if 'logical' in thisObject:
                    jobFESize += thisObject['logical']
                if 'bytesRead' in thisObject:
                    jobFESize += thisObject['bytesRead']
                if 'archiveLogical' in thisObject and thisObject['archiveLogical'] > 0:
                    jobFESize += thisObject['archiveLogical']
                if 'archiveBytesRead' in thisObject:
                    jobFESize += thisObject['archiveBytesRead']
                    isCad = True
            for object in sorted(objects.keys()):
                thisObject = objects[object]
                if ('logical' in thisObject and 'bytesRead' in thisObject) or ('archiveLogical' in thisObject and 'archiveBytesRead' in thisObject):
                    objFESize = round(thisObject['logical'] / multiplier, 1)
                    if thisObject['archiveLogical'] > 0:
                        objFESize = round(thisObject['archiveLogical'] / multiplier, 1)
                    objGrowth = round(thisObject['growth'] / (jobReduction * multiplier), 1)
                    if jobObjGrowth != 0:
                        objGrowth = round(jobGrowth * thisObject['growth'] / (jobObjGrowth * multiplier), 1)
                    objGrowth = objGrowth * resiliencyFactor
                    if jobFESize > 0:
                        objWeight = (thisObject['logical'] + thisObject['bytesRead']) / jobFESize
                        if thisObject['archiveLogical'] > 0:
                            objWeight = (thisObject['archiveLogical'] + thisObject['archiveBytesRead']) / jobFESize
                    else:
                        objWeight = 0
                    if jobWritten > 0:
                        objWritten = round(objWeight * jobWritten / multiplier, 1)
                    elif isCad is False:
                        objWritten = round(objFESize / jobReduction, 1)
                    else:
                        objWritten = 0
                    if dataIn > 0:
                        objDataIn = round(objWeight * dataIn / multiplier, 1)
                    elif isCad is False:
                        objDataIn = round(objFESize / jobReduction, 1)
                    else:
                        objDataIn = 0
                    objWrittenWithResiliency = round(objWritten * resiliencyFactor, 1)
                    sourceName = ''
                    if 'sourceId' in thisObject:
                        if thisObject['sourceId'] in sourceNames:
                            sourceName = sourceNames[thisObject['sourceId']]
                        else:
                            if debug is True:
                                print('   looking up source ID (2)')
                            source = api('get', 'protectionSources?id=%s&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true' % thisObject['sourceId'], quiet=True)
                            if source is not None and 'protectionSource' not in source and 'error' not in source and len(source) > 0:
                                source = source[0]
                            if source is not None and 'protectionSource' in source:
                                sourceName = source['protectionSource']['name']
                                sourceNames[thisObject['sourceId']] = sourceName
                    else:
                        sourceName = thisObject['name']
                    # archive Stats
                    totalArchived = 0
                    vaultStats = ''
                    if cloudStats is not None and 'dataTransferSummary' in cloudStats and len(cloudStats['dataTransferSummary']) > 0:
                        for vaultSummary in cloudStats['dataTransferSummary']:
                            if vaultSummary is not None and 'dataTransferPerProtectionJob' in vaultSummary and len(vaultSummary['dataTransferPerProtectionJob']) > 0:
                                for cloudJob in vaultSummary['dataTransferPerProtectionJob']:
                                    if cloudJob['protectionJobName'] == job['name']:
                                        if cloudJob['storageConsumed'] > 0:
                                            totalArchived += (objWeight * cloudJob['storageConsumed'])
                                            vaultStats += '[%s]%s ' % (vaultSummary['vaultName'], round((objWeight * cloudJob['storageConsumed']) / multiplier, 1))
                                            if isCad is True:
                                                jobReduction = round(jobFESize / cloudJob['storageConsumed'], 1)
                    totalArchived = round(totalArchived / multiplier, 1)
                    alloc = objFESize
                    if job['environment'] in ['kVMware', 'kAD'] or (job['environment'] == 'kPhysical' and job['physicalParams']['protectionType'] == 'kVolume'):
                        alloc = round(thisObject['alloc'] / multiplier, 1)
                    sumObjectsUsed += round(thisObject['logical'] / multiplier, 1)
                    # print(sumObjectsUsed)
                    sumObjectsWritten += objWritten
                    sumObjectsWrittenWithResiliency += objWrittenWithResiliency
                    newestBackup = '-'
                    try:
                        if 'newestBackup' in thisObject:
                            newestBackup = usecsToDate(thisObject['newestBackup'])
                    except Exception:
                        pass
                    oldestBackup = '-'
                    try:
                        if 'oldestBackup' in thisObject:
                            oldestBackup = usecsToDate(thisObject['oldestBackup'])
                    except Exception:
                        pass
                    csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], origin, statsAge, job['name'], tenant, sdid, sdname, job['environment'][1:], sourceName, thisObject['name'], alloc, objFESize, objDataIn, objWritten, objWrittenWithResiliency, jobReduction, objGrowth, thisObject['numSnaps'], thisObject['numLogs'], oldestBackup, newestBackup, thisObject['lastDataLock'], archiveCount, oldestArchive, totalArchived, vaultStats, jobDescription, thisObject['vmTags']))
        else:
            stats = viewRunStats
            if 'statsList' in stats and stats['statsList'] is not None:
                thisStat = [s for s in stats['statsList'] if s['id'] == int(v1JobId)]
            endUsecs = nowUsecs
            lastDataLock = '-'
            lastRunId = '0'
            while 1:
                if debug is True:
                    print('    getting protection runs')
                runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true' % (job['id'], numruns, endUsecs), v=2)
                if lastRunId != '0':
                    runs['runs'] = [r for r in runs['runs'] if r['id'] < lastRunId]
                for run in runs['runs']:
                    if 'isLocalSnapshotsDeleted' not in run:
                        # per object stats
                        if 'objects' in run and run['objects'] is not None and len(run['objects']) > 0:
                            for object in [o for o in run['objects']]:
                                runInfo = None
                                if 'localSnapshotInfo' in object:
                                    snap = object['localSnapshotInfo']
                                    runInfo = run['localBackupInfo']
                                elif 'orignialSnapshotInfo' in object:
                                    snap = object['originalBackupInfo']
                                    runInfo = run['originalBackupInfo']
                                else:
                                    # CAD
                                    snap = None
                                    if 'archivalInfo' in object:
                                        try:
                                            archivalInfo = object['archivalInfo']['archivalTargetResults'][0]
                                            runInfo = run['archivalInfo']['archivalTargetResults'][0]
                                        except Exception:
                                            archivalInfo = None
                                if runInfo is not None and lastDataLock == '-' and 'dataLockConstraints' in runInfo and 'expiryTimeUsecs' in runInfo['dataLockConstraints'] and runInfo['dataLockConstraints']['expiryTimeUsecs'] > 0:
                                    if runInfo['dataLockConstraints']['expiryTimeUsecs'] > nowUsecs:
                                        lastDataLock = usecsToDate(runInfo['dataLockConstraints']['expiryTimeUsecs'])
                                if object['object']['name'] not in viewHistory:
                                    viewHistory[object['object']['name']] = {}
                                    viewHistory[object['object']['name']]['stats'] = thisStat
                                    viewHistory[object['object']['name']]['numSnaps'] = 0
                                    viewHistory[object['object']['name']]['numLogs'] = 0
                                    viewHistory[object['object']['name']]['archiveCount'] = 0
                                    viewHistory[object['object']['name']]['oldestArchive'] = '-'
                                    viewHistory[object['object']['name']]['newestBackup'] = ''
                                    viewHistory[object['object']['name']]['oldestBackup'] = ''
                                    if snap is not None:
                                        viewHistory[object['object']['name']]['newestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                        viewHistory[object['object']['name']]['oldestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                if snap is not None:
                                    viewHistory[object['object']['name']]['oldestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                    viewHistory[object['object']['name']]['numSnaps'] += 1
                                viewHistory[object['object']['name']]['lastDataLock'] = lastDataLock
                    if 'archivalInfo' in run and run['archivalInfo'] is not None and 'archivalTargetResults' in run['archivalInfo'] and run['archivalInfo']['archivalTargetResults'] is not None and len(run['archivalInfo']['archivalTargetResults']) > 0:
                        for archiveResult in run['archivalInfo']['archivalTargetResults']:
                            if 'status' in archiveResult and archiveResult['status'] == 'Succeeded':
                                for object in [o for o in run['objects']]:
                                    if object['object']['name'] not in viewHistory:
                                        viewHistory[object['object']['name']] = {}
                                        viewHistory[object['object']['name']]['archiveCount'] = 0
                                        viewHistory[object['object']['name']]['oldestArchive'] = '-'
                                        viewHistory[object['object']['name']]['stats'] = thisStat
                                        viewHistory[object['object']['name']]['numSnaps'] = 0
                                        viewHistory[object['object']['name']]['numLogs'] = 0
                                        viewHistory[object['object']['name']]['newestBackup'] = None
                                        viewHistory[object['object']['name']]['oldestBackup'] = None
                                    viewHistory[object['object']['name']]['archiveCount'] += 1
                                    viewHistory[object['object']['name']]['oldestArchive'] = usecsToDate(run['id'].split(':')[-1])
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

    # views
    views = api('get', 'file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true&includeInactive=true', v=2)
    if 'views' in views and views['views'] is not None and len(views['views']) > 0:
        stats = api('get', 'stats/consumers?msecsBeforeCurrentTimeToCompare=%s&consumerType=kViews' % (growthdays * 86400000))
        viewJobStats = {}

        # build total view job consumptions
        for view in views['views']:
            jobName = None
            try:
                jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
                thisJob = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobName.lower()]
                if thisJob is not None and len(thisJob) > 0:
                    if thisJob[0]['isActive'] is not True:
                        origin = 'replica'
                    if thisJob[0]['environment'] == 'kRemoteAdapter':
                        continue

                if 'stats' in view:
                    viewStats = view['stats']['dataUsageStats']
                else:
                    continue
                if jobName not in viewJobAltStats:
                    viewJobAltStats[jobName] = {"totalConsumed": 0}
                viewJobAltStats[jobName]["totalConsumed"] += viewStats['storageConsumedBytes']
                if jobName not in viewJobStats:
                    viewJobStats[jobName] = viewHistory[view['name']]['stats']
            except Exception:
                pass

        for view in views['views']:
            if 'stats' not in view:
                continue
            viewStats = view['stats']['dataUsageStats']
            origin = 'local'
            try:
                jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
                thisJob = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobName.lower()]
                if thisJob is not None and len(thisJob) > 0:
                    if thisJob[0]['isActive'] is not True:
                        origin = 'replica'
                    if thisJob[0]['environment'] == 'kRemoteAdapter':
                        continue
            except Exception:
                jobName = '-'
            numSnaps = 0
            numLogs = 0
            oldestBackup = '-'
            newestBackup = '-'
            archiveCount = 0
            oldestArchive = '-'
            if jobName != '-':
                if view['name'] in viewHistory:
                    newestBackup = viewHistory[view['name']]['newestBackup']
                    oldestBackup = viewHistory[view['name']]['oldestBackup']
                    numSnaps = viewHistory[view['name']]['numSnaps']
                    oldestArchive = viewHistory[view['name']]['oldestArchive']
                    archiveCount = viewHistory[view['name']]['archiveCount']
            sourceName = view['storageDomainName']
            viewName = view['name']
            print('  %s' % viewName)
            tenant = ''
            if 'tenantId' in view and view['tenantId'] is not None:
                tenant = view['tenantId'][:-1]
            objFESize = round(viewStats['totalLogicalUsageBytes'] / multiplier, 1)
            sumObjectsUsed += objFESize
            dataIn = 0
            dataInAfterDedup = 0
            jobWritten = 0
            consumption = 0
            objWeight = 1
            statsAge = '-'
            objGrowth = 0
            if jobName != '-' and jobName in viewJobStats and len(viewJobStats[jobName]) > 0:
                if viewJobAltStats[jobName]["totalConsumed"] == 0:
                    objWeight = 0
                else:
                    objWeight = viewStats['storageConsumedBytes'] / viewJobAltStats[jobName]["totalConsumed"]
                if 'dataInBytes' in viewJobStats[jobName][0]['stats']:
                    dataIn = viewJobStats[jobName][0]['stats']['dataInBytes'] * objWeight
                if 'dataInBytesAfterDedup' in viewJobStats[jobName][0]['stats']:
                    dataInAfterDedup = viewJobStats[jobName][0]['stats']['dataInBytesAfterDedup'] * objWeight
                if 'dataWrittenBytes' in viewJobStats[jobName][0]['stats']:
                    jobWritten = viewJobStats[jobName][0]['stats']['dataWrittenBytes'] * objWeight
                if 'localTotalPhysicalUsageBytes' in viewJobStats[jobName][0]['stats']:
                    consumption =  viewJobStats[jobName][0]['stats']['localTotalPhysicalUsageBytes'] * objWeight
                if 'storageConsumedBytes' in viewJobStats[jobName][0]['stats'] and 'storageConsumedBytesPrev' in viewJobStats[jobName][0]['stats']:
                    objGrowth = round(objWeight * (viewJobStats[jobName][0]['stats']['storageConsumedBytes'] - viewJobStats[jobName][0]['stats']['storageConsumedBytesPrev']) / multiplier, 1)
            else:
                dataIn = viewStats.get('dataInBytes', 0)
                dataInAfterDedup = viewStats.get('dataInBytesAfterDedup', 0)
                jobWritten = viewStats.get('dataWrittenBytes', 0)
                consumption = viewStats.get('localTotalPhysicalUsageBytes', 0)
                try:
                    objGrowth = round((viewStats.get('storageConsumedBytes', 0) - viewStats.get('storageConsumedBytesPrev', 0)) / multiplier, 1)
                except Exception:
                    pass
            statsTimeUsecs = view['stats']['dataUsageStats'].get('dataWrittenBytesTimestampUsec', 0)
            if statsTimeUsecs > 0:
                statsAge = round((nowUsecs - statsTimeUsecs) / 86400000000, 0)
            else:
                statsTime = '-'
            sumObjectsWritten += round(jobWritten / multiplier, 1)
            sumObjectsWrittenWithResiliency += round(consumption / multiplier, 1)

            if dataInAfterDedup > 0 and jobWritten > 0:
                dedup = round(float(dataIn) / dataInAfterDedup, 1)
                compression = round(float(dataInAfterDedup) / jobWritten, 1)
                jobReduction = round((float(dataIn) / dataInAfterDedup) * (float(dataInAfterDedup) / jobWritten), 1)
            else:
                jobReduction = 1

            # archive Stats
            totalArchived = 0
            vaultStats = ''
            if cloudStats is not None and 'dataTransferSummary' in cloudStats and len(cloudStats['dataTransferSummary']) > 0:
                for vaultSummary in cloudStats['dataTransferSummary']:
                    if vaultSummary is not None and 'dataTransferPerProtectionJob' in vaultSummary and len(vaultSummary['dataTransferPerProtectionJob']) > 0:
                        for cloudJob in vaultSummary['dataTransferPerProtectionJob']:
                            if cloudJob['protectionJobName'] == jobName:
                                if cloudJob['storageConsumed'] > 0:
                                    totalArchived += (objWeight * cloudJob['storageConsumed'])
                                    vaultStats += '[%s]%s ' % (vaultSummary['vaultName'], round((objWeight * cloudJob['storageConsumed']) / multiplier, 1))
            totalArchived = round(totalArchived / multiplier, 1)
            viewDescription = ''
            if 'description' in view:
                viewDescription = view['description']
            try:
                lastDataLock = viewHistory[view['name']]['lastDataLock']
            except Exception:
                lastDataLock = '-'
            csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], origin, statsAge, jobName, tenant, view['storageDomainId'], view['storageDomainName'], 'View', sourceName, viewName, objFESize, objFESize, round(dataIn / multiplier, 1), round(jobWritten / multiplier, 1), round(consumption / multiplier, 1), jobReduction, objGrowth, numSnaps, numLogs, oldestBackup, newestBackup, lastDataLock, archiveCount, oldestArchive, totalArchived, vaultStats, viewDescription, ''))
    
    garbageStart = int(midnightusecs / 1000)
    bookKeeperStart = int(midnightusecs / 1000 - (29 * 86400000))
    bookKeeperEnd = int(midnightusecs / 1000 + 86400000)
    bookKeeperStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=MRCounters&metricName=bytes_value&rollupIntervalSecs=180&rollupFunction=average&entityId=BookkeeperChunkBytesPhysical&endTimeMsecs=%s' % (bookKeeperStart, bookKeeperEnd))
    try:
        bookKeeperBytes = bookKeeperStats['dataPointVec'][-1]['data']['int64Value']
    except Exception:
        print('*** Error getting bookkeeper stats ***')
        bookKeeperBytes = 0
    clusterUsedBytes = cluster['stats']['usagePerfStats']['totalPhysicalUsageBytes']
    unaccounted = clusterUsedBytes - bookKeeperBytes
    unaccountedPercent = 0
    garbageStats = api('get', 'statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kMorphedGarbageBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=360&schemaName=kBridgeClusterStats&startTimeMsecs=%s' % (bookKeeperEnd, cluster['id'], garbageStart))
    garbagePercent = 0
    try:
        garbageBytes = garbageStats['dataPointVec'][-1]['data']['int64Value']
    except Exception:
        garbageBytes = 0
    otherUnaccountedBytes = unaccounted - garbageBytes
    otherUnaccountedPercent = 0
    if clusterUsedBytes > 0:
        unaccountedPercent = round(100 * (unaccounted / clusterUsedBytes), 1)
        garbagePercent = round(100 * (garbageBytes / clusterUsedBytes), 1)
        otherUnaccountedPercent = unaccountedPercent - garbagePercent

    storageVarianceFactor = 1
    if sumObjectsWrittenWithResiliency > 0:
        storageVarianceFactor = round(clusterUsed / sumObjectsWrittenWithResiliency, 4)
    clusterStats.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], clusterUsed, round(bookKeeperBytes / multiplier, 1), round(unaccounted / multiplier, 1), unaccountedPercent, round(garbageBytes / multiplier, 1), garbagePercent, round(otherUnaccountedBytes / multiplier, 1), otherUnaccountedPercent, clusterReduction, sumObjectsUsed, sumObjectsWritten, sumObjectsWrittenWithResiliency, storageVarianceFactor, scriptVersion, cluster['clusterSoftwareVersion']))


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
            reportStorage()
    else:
        reportStorage()

csv.close()
clusterStats.close()
print('\n       Output saved to: %s' % csvfileName)
print('Cluster stats saved to: %s\n' % clusterStatsFileName)

