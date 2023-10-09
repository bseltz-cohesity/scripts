#!/usr/bin/env python
"""Storage Per Object Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
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

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
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

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

print('Collecting report data...')

cluster = api('get', 'cluster?fetchStats=true')

try:
    clusterReduction = round(cluster['stats']['usagePerfStats']['dataInBytes'] / cluster['stats']['usagePerfStats']['dataInBytesAfterjobReduction'], 1)
except Exception:
    clusterReduction = 1

title = 'Storage Report for %s' % cluster['name']

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
growthdaysusecs = timeAgo(growthdays, 'days')
msecsBeforeCurrentTimeToCompare = growthdays * 24 * 60 * 60 * 1000
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/storagePerObjectReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Job Name","Tenant","Environment","Source Name","Object Name","Logical %s","%s Written","%s Written plus Resiliency","Job Reduction Ratio","%s Written Last %s Days","%s Archived","%s per Archive Target"\n' % (units, units, units, units, growthdays, units, units))

vaults = api('get', 'vaults')
if vaults is not None and len(vaults) > 0:
    nowMsecs = int((dateToUsecs()) / 1000)
    weekAgoMsecs = nowMsecs - 86400000
    cloudStatURL = 'reports/dataTransferToVaults?endTimeMsecs=%s&startTimeMsecs=%s' % (nowMsecs, weekAgoMsecs)
    for vault in vaults:
        cloudStatURL += '&vaultIds=%s' % vault['id']
    cloudStats = api('get', cloudStatURL)


if skipdeleted:
    jobs = api('get', 'data-protect/protection-groups?isDeleted=false&includeTenants=true', v=2)
else:
    jobs = api('get', 'data-protect/protection-groups?includeTenants=true', v=2)

storageDomains = api('get', 'viewBoxes')

sourceNames = {}
for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if job['environment'] not in ['kView', 'kRemoteAdapter']:
        tenant = ''
        if 'permissions' in job and len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
            tenant = job['permissions'][0]['name']

        # get resiliency factor
        resiliencyFactor = 0
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
        print(job['name'])
        v1JobId = job['id'].split(':')[2]
        jobObjGrowth = 0
        jobGrowth = 0
        # get jobReduction factor
        if job['isActive'] is True:
            stats = api('get', 'stats/consumers?consumerType=kProtectionRuns&consumerIdList=%s&msecsBeforeCurrentTimeToCompare=%s' % (v1JobId, msecsBeforeCurrentTimeToCompare))
        else:
            stats = api('get', 'stats/consumers?consumerType=kReplicationRuns&consumerIdList=%s&msecsBeforeCurrentTimeToCompare=%s' % (v1JobId, msecsBeforeCurrentTimeToCompare))
        if 'statsList' in stats and stats['statsList'] is not None:
            dataIn = stats['statsList'][0]['stats'].get('dataInBytes', 0)
            dataInAfterDedup = stats['statsList'][0]['stats'].get('dataInBytesAfterDedup', 0)
            jobWritten = stats['statsList'][0]['stats'].get('dataWrittenBytes', 0)
            storageConsumedBytes = stats['statsList'][0]['stats'].get('storageConsumedBytes', 0)
            storageConsumedBytesPrev = stats['statsList'][0]['stats'].get('storageConsumedBytesPrev', 0)
            if storageConsumedBytes > 0 and storageConsumedBytesPrev > 0:
                jobGrowth = (storageConsumedBytes - storageConsumedBytesPrev) / resiliencyFactor
            if dataInAfterDedup > 0 and jobWritten > 0:
                dedup = round(float(dataIn) / dataInAfterDedup, 1)
                compression = round(float(dataInAfterDedup) / jobWritten, 1)
                jobReduction = round((float(dataIn) / dataInAfterDedup) * (float(dataInAfterDedup) / jobWritten), 1)
            else:
                jobReduction = 1
        else:
            jobWritten = 0
            jobReduction = clusterReduction
        if jobReduction == 0:
            jobReduction = 1
        endUsecs = nowUsecs

        # get protection runs in retention
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true&includeObjectDetails=true&excludeNonRestorableRuns=true' % (job['id'], numruns, endUsecs), v=2)
            if len(runs['runs']) > 0:
                if 'localBackupInfo' in runs['runs'][-1]:
                    endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
                else:
                    endUsecs = runs['runs'][-1]['originalBackupInfo']['startTimeUsecs'] - 1
            else:
                break
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
                            else:
                                snap = object['originalBackupInfo']
                            try:
                                if objId not in objects and not (job['environment'] == 'kAD' and object['object']['environment'] == 'kAD') and not (job['environment'] in ['kSQL', 'kOracle'] and object['object']['objectType'] == 'kHost'):

                                    objects[objId] = {}
                                    objects[objId]['name'] = object['object']['name']
                                    objects[objId]['logical'] = 0
                                    objects[objId]['bytesRead'] = 0
                                    objects[objId]['growth'] = 0
                                    if 'sourceId' in object['object']:
                                        objects[objId]['sourceId'] = object['object']['sourceId']
                                    if 'logicalSizeBytes' not in snap['snapshotInfo']['stats']:
                                        csource = api('get', 'protectionSources?id=%s' % objId, quiet=True)
                                        try:
                                            if type(csource) == list:
                                                objects[objId]['logical'] = csource[0]['protectedSourcesSummary'][0]['totalLogicalSize']
                                            else:
                                                objects[objId]['logical'] = csource['protectedSourcesSummary'][0]['totalLogicalSize']
                                        except Exception:
                                            pass
                                    else:
                                        objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                if objId in objects and 'logicalSizeBytes' in snap['snapshotInfo']['stats'] and snap['snapshotInfo']['stats']['logicalSizeBytes'] > objects[objId]['logical']:
                                    objects[objId]['logical'] = snap['snapshotInfo']['stats']['logicalSizeBytes']
                                objects[objId]['bytesRead'] += snap['snapshotInfo']['stats']['bytesRead']
                                if snap['snapshotInfo']['startTimeUsecs'] > growthdaysusecs:
                                    objects[objId]['growth'] += snap['snapshotInfo']['stats']['bytesRead']
                                    jobObjGrowth += snap['snapshotInfo']['stats']['bytesRead']
                            except Exception as e:
                                pass

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
                objWrittenWithResiliency = objWritten * resiliencyFactor
                sourceName = ''
                if 'sourceId' in thisObject:
                    if thisObject['sourceId'] in sourceNames:
                        sourceName = sourceNames[thisObject['sourceId']]
                    else:
                        source = api('get', 'protectionSources?id=%s&excludeTypes=kFolder,kDatacenter,kComputeResource,kClusterComputeResource,kResourcePool,kDatastore,kHostSystem,kVirtualMachine,kVirtualApp,kStandaloneHost,kStoragePod,kNetwork,kDistributedVirtualPortgroup,kTagCategory,kTag' % thisObject['sourceId'])
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
                csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (job['name'], tenant, job['environment'], sourceName, thisObject['name'], objFESize, objWritten, objWrittenWithResiliency, jobReduction, objGrowth, totalArchived, vaultStats))

# views
views = api('get', 'file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true', v=2)
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
        viewJobStats[jobName] += view['stats']['dataUsageStats']['totalLogicalUsageBytes']

    for view in views['views']:
        try:
            jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
        except Exception:
            jobName = '-'
        sourceName = view['storageDomainName']
        viewName = view['name']
        print(viewName)
        tenant = ''
        if 'tenantId' in view and view['tenantId'] is not None:
            tenant = view['tenantId'][:-1]
        dataIn = 0
        dataInAfterDedup = 0
        jobWritten = 0
        consumption = 0
        objWeight = 1
        try:
            objFESize = round(view['stats']['dataUsageStats']['totalLogicalUsageBytes'] / multiplier, 1)
            dataIn = view['stats']['dataUsageStats'].get('dataInBytes', 0)
            dataInAfterDedup = view['stats']['dataUsageStats'].get('dataInBytesAfterDedup', 0)
            jobWritten = view['stats']['dataUsageStats'].get('dataWrittenBytes', 0)
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
                            # print(cloudJob['storageConsumed'])
                            if cloudJob['storageConsumed'] > 0:
                                totalArchived += (objWeight * cloudJob['storageConsumed'])
                                vaultStats += '[%s]%s ' % (vaultSummary['vaultName'], round((objWeight * cloudJob['storageConsumed']) / multiplier, 1))
        totalArchived = round(totalArchived / multiplier, 1)
        csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (jobName, tenant, 'kView', sourceName, viewName, objFESize, round(jobWritten / multiplier, 1), round(consumption / multiplier, 1), jobReduction, objGrowth, totalArchived, vaultStats))
csv.close()
print('\nOutput saved to %s\n' % csvfileName)
