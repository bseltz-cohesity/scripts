#!/usr/bin/env python
"""Storage Per Object Report for Python"""

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
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-y', '--growthdays', type=int, default=7)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
parser.add_argument('-s', '--skipdeleted', action='store_true')
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
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
growthdaysusecs = timeAgo(growthdays, 'days')
msecsBeforeCurrentTimeToCompare = growthdays * 24 * 60 * 60 * 1000
datestring = now.strftime("%Y-%m-%d-%H-%M")
csvfileName = '%s/storagePerObjectReport-%s.csv' % (folder, datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Origin","Stats Age (Days)","Protection Group","Tenant","Environment","Source Name","Object Name","Logical Size %s","%s Read","%s Written","%s Written plus Resiliency","Protection Group Reduction Ratio","%s Growth Last %s Days","Snapshots","Log Backups","Oldest Backup","Newest Backup","Archive Count","Oldest Archive","%s Archived","%s per Archive Target"\n' % (units, units, units, units, units, growthdays, units, units))


def reportStorage():
    viewHistory = {}
    cluster = api('get', 'cluster?fetchStats=true')
    print('\n%s' % cluster['name'])
    # print('  Collecting report data...')
    try:
        clusterReduction = round(cluster['stats']['usagePerfStats']['dataInBytes'] / cluster['stats']['usagePerfStats']['dataInBytesAfterjobReduction'], 1)
    except Exception:
        clusterReduction = 1
    vaults = api('get', 'vaults?includeFortKnoxVault=true')
    cloudStats = None
    if vaults is not None and len(vaults) > 0:
        nowMsecs = int((dateToUsecs()) / 1000)
        weekAgoMsecs = nowMsecs - 86400000
        cloudStatURL = 'reports/dataTransferToVaults?endTimeMsecs=%s&startTimeMsecs=%s' % (nowMsecs, weekAgoMsecs)
        for vault in vaults:
            cloudStatURL += '&vaultIds=%s' % vault['id']
        cloudStats = api('get', cloudStatURL)
    if skipdeleted:
        jobs = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true&useCachedData=true&onlyReturnBasicSummary=true', v=2)
    else:
        jobs = api('get', 'data-protect/protection-groups?includeTenants=true&useCachedData=true&onlyReturnBasicSummary=true', v=2)

    storageDomains = api('get', 'viewBoxes')

    sourceNames = {}
    cookie = ''
    localStats = {'statsList': []}
    while True:
        theseStats = api('get', 'stats/consumers?consumerType=kProtectionRuns&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (msecsBeforeCurrentTimeToCompare, cookie))
        if 'statsList' in theseStats:
            localStats['statsList'] = localStats['statsList'] + theseStats['statsList']
        if 'cookie' in theseStats:
            cookie = theseStats['cookie']
        else:
            cookie = ''
        if cookie == '':
            break
    cookie = ''
    replicaStats = {'statsList': []}
    while True:
        replicaStats = api('get', 'stats/consumers?consumerType=kReplicationRuns&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (msecsBeforeCurrentTimeToCompare, cookie))
        if 'statsList' in theseStats:
            replicaStats['statsList'] = replicaStats['statsList'] + theseStats['statsList']
        if 'cookie' in theseStats:
            cookie = theseStats['cookie']
        else:
            cookie = ''
        if cookie == '':
            break
    for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
        statsAge = '-'
        origin = 'local'
        if job['isActive'] is not True:
            origin = 'replica'
        if job['environment'] not in ['kView', 'kRemoteAdapter']:
            tenant = ''
            if 'permissions' in job and len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
                tenant = job['permissions'][0]['name']
            # get resiliency factor
            resiliencyFactor = 1
            if 'storageDomainId' in job:
                sd = [v for v in storageDomains if v['id'] == job['storageDomainId']]
                if sd is not None and len(sd) > 0:
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
            v1JobId = job['id'].split(':')[2]
            jobObjGrowth = 0
            jobGrowth = 0
            # get jobReduction factor
            if job['isActive'] is True:
                stats = localStats
            else:
                stats = replicaStats
            if 'statsList' in stats and stats['statsList'] is not None:
                thisStat = [s for s in stats['statsList'] if s['name'] == job['name']]
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

            # get protection runs in retention
            archiveCount = 0
            oldestArchive = '-'
            endUsecs = nowUsecs
            while 1:
                if debug is True:
                    print('    getting protection runs')
                runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true' % (job['id'], numruns, endUsecs), v=2)
                for run in runs['runs']:
                    if 'isLocalSnapshotsDeleted' not in run:
                        # per object stats
                        if 'objects' in run and run['objects'] is not None and len(run['objects']) > 0:
                            for object in [o for o in run['objects'] if o['object']['environment'] != job['environment']]:
                                sourceNames[object['object']['id']] = object['object']['name']
                            for object in [o for o in run['objects']]:
                                objId = object['object']['id']
                                if 'localSnapshotInfo' in object:
                                    snap = object['localSnapshotInfo']
                                    runType = run['localBackupInfo']['runType']
                                else:
                                    snap = object['originalBackupInfo']
                                    runType = run['originalBackupInfo']['runType']
                                try:
                                    if objId not in objects and not (job['environment'] == 'kAD' and object['object']['environment'] == 'kAD') and not (job['environment'] in ['kSQL', 'kOracle'] and object['object']['objectType'] == 'kHost'):

                                        objects[objId] = {}
                                        objects[objId]['name'] = object['object']['name']
                                        objects[objId]['logical'] = 0
                                        objects[objId]['bytesRead'] = 0
                                        objects[objId]['growth'] = 0
                                        objects[objId]['numSnaps'] = 0
                                        objects[objId]['numLogs'] = 0
                                        objects[objId]['newestBackup'] = snap['snapshotInfo']['startTimeUsecs']
                                        objects[objId]['oldestBackup'] = snap['snapshotInfo']['startTimeUsecs']
                                        if 'sourceId' in object['object']:
                                            objects[objId]['sourceId'] = object['object']['sourceId']
                                        if 'logicalSizeBytes' not in snap['snapshotInfo']['stats']:
                                            if debug is True:
                                                print('   looking up source ID')
                                            csource = api('get', 'protectionSources?id=%s&useCachedData=true' % objId, quiet=True)
                                            try:
                                                if type(csource) is list:
                                                    objects[objId]['logical'] = csource[0]['protectedSourcesSummary'][0]['totalLogicalSize']
                                                else:
                                                    objects[objId]['logical'] = csource['protectedSourcesSummary'][0]['totalLogicalSize']
                                            except Exception:
                                                pass
                                        else:
                                            objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                        if job['environment'] == 'kVMware':
                                            vmsearch = api('get', '/searchvms?allUnderHierarchy=true&entityTypes=kVMware&jobIds=%s&vmName=%s' % (job['id'].split(':')[2], object['object']['name']))
                                            if vmsearch is not None and 'vms' in vmsearch and vmsearch['vms'] is not None and len(vmsearch['vms']) > 0:
                                                vms = [vm for vm in vmsearch['vms'] if vm['vmDocument']['objectName'].lower() == object['object']['name'].lower()]
                                                if len(vms) > 0:
                                                    vmbytes = vms[0]['vmDocument']['objectId']['entity']['vmwareEntity']['frontEndSizeInfo']['sizeBytes']
                                                    objects[objId]['logical'] = vmbytes
                                    if objId in objects and 'logicalSizeBytes' in snap['snapshotInfo']['stats'] and snap['snapshotInfo']['stats']['logicalSizeBytes'] > objects[objId]['logical']:
                                        if job['environment'] != 'kVMware' or objects[objId]['logical'] == 0:
                                            objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                    if job['environment'] == 'kVMware' and snap['snapshotInfo']['stats']['logicalSizeBytes'] < objects[objId]['logical']:
                                        objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                    objects[objId]['bytesRead'] += snap['snapshotInfo']['stats']['bytesRead']
                                    if snap['snapshotInfo']['startTimeUsecs'] > growthdaysusecs:
                                        objects[objId]['growth'] += snap['snapshotInfo']['stats']['bytesRead']
                                        jobObjGrowth += snap['snapshotInfo']['stats']['bytesRead']
                                    if runType == 'kLog':
                                        objects[objId]['numLogs'] += 1
                                    else:
                                        objects[objId]['numSnaps'] += 1
                                    objects[objId]['oldestBackup'] = snap['snapshotInfo']['startTimeUsecs']

                                except Exception as e:
                                    pass
                    if 'archivalInfo' in run and run['archivalInfo'] is not None and 'archivalTargetResults' in run['archivalInfo'] and run['archivalInfo']['archivalTargetResults'] is not None and len(run['archivalInfo']['archivalTargetResults']) > 0:
                        for archiveResult in run['archivalInfo']['archivalTargetResults']:
                            if 'status' in archiveResult and archiveResult['status'] == 'Succeeded':
                                archiveCount += 1
                                oldestArchive = usecsToDate(run['id'].split(':')[-1])
                if len(runs['runs']) < numruns:
                    break
                else:
                    if 'localBackupInfo' in runs['runs'][-1]:
                        endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
                    else:
                        endUsecs = runs['runs'][-1]['originalBackupInfo']['startTimeUsecs'] - 1

            # process output
            jobFESize = 0
            for object in sorted(objects.keys()):
                thisObject = objects[object]
                if 'logical' in thisObject:
                    jobFESize += thisObject['logical']
                if 'bytesRead' in thisObject:
                    jobFESize += thisObject['bytesRead']
            for object in sorted(objects.keys()):
                thisObject = objects[object]
                if 'logical' in thisObject and 'bytesRead' in thisObject:
                    objFESize = round(thisObject['logical'] / multiplier, 1)
                    objGrowth = round(thisObject['growth'] / (jobReduction * multiplier), 1)
                    if jobObjGrowth != 0:
                        objGrowth = round(jobGrowth * thisObject['growth'] / (jobObjGrowth * multiplier), 1)
                    if jobFESize > 0:
                        objWeight = (thisObject['logical'] + thisObject['bytesRead']) / jobFESize
                    else:
                        objWeight = 0
                    if jobWritten > 0:
                        objWritten = round(objWeight * jobWritten / multiplier, 1)
                    else:
                        objWritten = round(objFESize / jobReduction, 1)
                    if dataIn > 0:
                        objDataIn = round(objWeight * dataIn / multiplier, 1)
                    else:
                        objDataIn = round(objFESize / jobReduction, 1)
                    objWrittenWithResiliency = round(objWritten * resiliencyFactor, 1)
                    sourceName = ''
                    if 'sourceId' in thisObject:
                        if thisObject['sourceId'] in sourceNames:
                            sourceName = sourceNames[thisObject['sourceId']]
                        else:
                            if debug is True:
                                print('   looking up source ID (2)')
                            source = api('get', 'protectionSources?id=%s&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag&useCachedData=true' % thisObject['sourceId'])
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
                    totalArchived = round(totalArchived / multiplier, 1)
                    csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], origin, statsAge, job['name'], tenant, job['environment'][1:], sourceName, thisObject['name'], objFESize, objDataIn, objWritten, objWrittenWithResiliency, jobReduction, objGrowth, thisObject['numSnaps'], thisObject['numLogs'], usecsToDate(thisObject['oldestBackup']), usecsToDate(thisObject['newestBackup']), archiveCount, oldestArchive, totalArchived, vaultStats))
        else:
            if job['isActive'] is True:
                stats = localStats
            else:
                stats = replicaStats
            if 'statsList' in stats and stats['statsList'] is not None:
                thisStat = [s for s in stats['statsList'] if s['name'] == job['name']]
            endUsecs = nowUsecs
            while 1:
                if debug is True:
                    print('    getting protection runs')
                runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true&useCachedData=true' % (job['id'], numruns, endUsecs), v=2)
                for run in runs['runs']:
                    if 'isLocalSnapshotsDeleted' not in run:
                        # per object stats
                        if 'objects' in run and run['objects'] is not None and len(run['objects']) > 0:
                            for object in [o for o in run['objects']]:
                                if 'localSnapshotInfo' in object:
                                    snap = object['localSnapshotInfo']
                                else:
                                    snap = object['originalBackupInfo']
                                if object['object']['name'] not in viewHistory:
                                    viewHistory[object['object']['name']] = {}
                                    viewHistory[object['object']['name']]['stats'] = thisStat
                                    viewHistory[object['object']['name']]['numSnaps'] = 0
                                    viewHistory[object['object']['name']]['numLogs'] = 0
                                    viewHistory[object['object']['name']]['archiveCount'] = 0
                                    viewHistory[object['object']['name']]['oldestArchive'] = '-'
                                    viewHistory[object['object']['name']]['newestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                    viewHistory[object['object']['name']]['oldestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                viewHistory[object['object']['name']]['oldestBackup'] = usecsToDate(snap['snapshotInfo']['startTimeUsecs'])
                                viewHistory[object['object']['name']]['numSnaps'] += 1
                    if 'archivalInfo' in run and run['archivalInfo'] is not None and 'archivalTargetResults' in run['archivalInfo'] and run['archivalInfo']['archivalTargetResults'] is not None and len(run['archivalInfo']['archivalTargetResults']) > 0:
                        for archiveResult in run['archivalInfo']['archivalTargetResults']:
                            if 'status' in archiveResult and archiveResult['status'] == 'Succeeded':
                                viewHistory[object['object']['name']]['archiveCount'] += 1
                                viewHistory[object['object']['name']]['oldestArchive'] = usecsToDate(run['id'].split(':')[-1])
                if len(runs['runs']) < numruns:
                    break
                else:
                    if 'localBackupInfo' in runs['runs'][-1]:
                        endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
                    else:
                        endUsecs = runs['runs'][-1]['originalBackupInfo']['startTimeUsecs'] - 1

    # views
    views = api('get', 'file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true&includeInactive=true', v=2)
    if 'views' in views and views['views'] is not None and len(views['views']) > 0:
        stats = api('get', 'stats/consumers?msecsBeforeCurrentTimeToCompare=%s&consumerType=kViews' % (growthdays * 86400000))
        # build total job FE sizes
        viewJobStats = {}
        for view in views['views']:
            try:
                jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
            except Exception:
                jobName = '-'
            if jobName not in viewJobStats:
                viewJobStats[jobName] = 0
            if 'stats' in view:
                viewJobStats[jobName] += view['stats']['dataUsageStats']['totalLogicalUsageBytes']
            elif view['name'] in viewHistory:
                view['stats'] = {'dataUsageStats': viewHistory[view['name']]['stats'][0]['stats']}
            else:
                continue
        for view in views['views']:
            if 'stats' not in view:
                continue
            origin = 'local'
            try:
                jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
                thisJob = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobName.lower()]
                if thisJob is not None and len(thisJob) > 0:
                    if thisJob[0]['isActive'] is not True:
                        origin = 'replica'
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
            dataIn = 0
            dataInAfterDedup = 0
            jobWritten = 0
            consumption = 0
            objWeight = 1
            statsAge = '-'
            try:
                objFESize = round(view['stats']['dataUsageStats']['totalLogicalUsageBytes'] / multiplier, 1)
                dataIn = view['stats']['dataUsageStats'].get('dataInBytes', 0)
                dataInAfterDedup = view['stats']['dataUsageStats'].get('dataInBytesAfterDedup', 0)
                jobWritten = view['stats']['dataUsageStats'].get('dataWrittenBytes', 0)
                statsTimeUsecs = view['stats']['dataUsageStats'].get('dataWrittenBytesTimestampUsec', 0)
                if statsTimeUsecs > 0:
                    statsAge = round((nowUsecs - statsTimeUsecs) / 86400000000, 0)
                else:
                    statsTime = '-'
                consumption = view['stats']['dataUsageStats'].get('localTotalPhysicalUsageBytes', 0)
                if jobName != '-':
                    objWeight = view['stats']['dataUsageStats']['totalLogicalUsageBytes'] / viewJobStats[jobName]
            except Exception:
                pass
            if dataInAfterDedup > 0 and jobWritten > 0:
                dedup = round(float(dataIn) / dataInAfterDedup, 1)
                compression = round(float(dataInAfterDedup) / jobWritten, 1)
                jobReduction = round((float(dataIn) / dataInAfterDedup) * (float(dataInAfterDedup) / jobWritten), 1)
            else:
                jobReduction = 1
            try:
                stat = [s for s in stats['statsList'] if s['name'] == viewName]
                if stat is not None and len(stat) > 0:
                    if 'storageConsumedBytesPrev' not in stat[0]['stats']:
                        stat[0]['stats']['storageConsumedBytesPrev'] = 0
                    objGrowth = round((stat[0]['stats']['storageConsumedBytes'] - stat[0]['stats']['storageConsumedBytesPrev']) / multiplier, 1)
            except Exception:
                objGrowth = 0
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
            csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], origin, statsAge, jobName, tenant, 'View', sourceName, viewName, objFESize, round(dataIn / multiplier, 1), round(jobWritten / multiplier, 1), round(consumption / multiplier, 1), jobReduction, objGrowth, numSnaps, numLogs, oldestBackup, newestBackup, archiveCount, oldestArchive, totalArchived, vaultStats))


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
print('\nOutput saved to %s\n' % csvfileName)
