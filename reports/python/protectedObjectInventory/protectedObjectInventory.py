#!/usr/bin/env python
"""List Protected Objects 2021-12-11 for python"""

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
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')

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

cluster = api('get', 'cluster')

print('\nGathering Job Info from %s...\n' % cluster['name'])

# outfile
now = datetime.now()
dateString = now.strftime("%Y-%m-%d")
outfile = 'protectedObjectInventory-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# gather info
sources = api('get', 'protectionSources/rootNodes')
policies = api('get', 'data-protect/policies', v=2)['policies']
jobs = api('get', 'data-protect/protection-groups?includeTenants=true&isDeleted=false&isActive=true', v=2)

# headings
f.write('Cluster Name,Job Name,Environment,Parent,Object Name,Object Type,Object Size (MiB),Policy Name,Direct Archive,Last Backup,Last Status,Last Run Type,Job Paused,Indexed,Start Time,Time Zone,QoS Policy,Priority,Full SLA,Incremental SLA,Incremental Schedule,Full Schedule,Log Schedule,Retries,Replication Schedule,Archive Schedule\n')

frequentSchedules = ['Minutes', 'Hours', 'Days']

# list policies
policyDetails = {}

for policy in policies:
    incrementalSchedule = ''
    fullSchedule = ''
    logSchedule = ''
    retries = ''
    replicationSchedule = ''
    archiveSchedule = ''

    if 'retryOptions' in policy:
        retries = '%s times every %s minutes' % (policy['retryOptions']['retries'], policy['retryOptions']['retryIntervalMins'])
    # base retention
    baseRetention = policy['backupPolicy']['regular']['retention']
    dataLock = ''
    if 'dataLockConfig' in baseRetention and baseRetention['dataLockConfig'] is not None:
        dataLock = ' : datalock for %s %s' % (baseRetention['dataLockConfig']['duration'], baseRetention['dataLockConfig']['unit'])
    if 'dataLock' in policy:
        dataLock = ' : datalock for %s %s' % (baseRetention['duration'], baseRetention['unit'])
    # incremental backup
    if 'incremental' in policy['backupPolicy']['regular']:
        backupSchedule = policy['backupPolicy']['regular']['incremental']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        if unit in frequentSchedules:
            frequency = backupSchedule[unitPath]['frequency']
            incrementalSchedule = 'Every %s %s keep for %s %s%s; ' % (frequency, unit, baseRetention['duration'], baseRetention['unit'], dataLock)
        else:
            if unit == 'Weeks':
                incrementalSchedule += 'Weekly on %s keep for %s %s%s; ' % ((':'.join(backupSchedule[unitPath]['dayOfWeek'])), baseRetention['duration'], baseRetention['unit'], dataLock)
            if unit == 'Months':
                incrementalSchedule += 'Monthly on %s %s keep for %s %s%s; ' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], baseRetention['duration'], baseRetention['unit'], dataLock)
    # full backup
    if 'full' in policy['backupPolicy']['regular']:
        backupSchedule = policy['backupPolicy']['regular']['full']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        if unit in frequentSchedules:
            frequency = backupSchedule[unitPath]['frequency']
            fullSchedule = 'Every %s %s keep for %s %s%s; ' % (frequency, unit, baseRetention['duration'], baseRetention['unit'], dataLock)
        else:
            if unit == 'Weeks':
                fullSchedule += 'weekly on %s keep for %s %s%s; ' % ((':'.join(backupSchedule[unitPath]['dayOfWeek'])), baseRetention['duration'], baseRetention['unit'], dataLock)
            if unit == 'Months':
                fullSchedule += 'Monthly on %s %s keep for %s %s%s; ' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], baseRetention['duration'], baseRetention['unit'], dataLock)
            if unit == 'ProtectOnce':
                fullSchedule += 'Once keep for %s %s%s; ' % (baseRetention['duration'], baseRetention['unit'], dataLock)
    # full backup
    if 'fullBackups' in policy['backupPolicy']['regular'] and policy['backupPolicy']['regular']['fullBackups'] is not None and len(policy['backupPolicy']['regular']['fullBackups']) > 0:
        backupSchedule = policy['backupPolicy']['regular']['fullBackups'][0]['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        thisRetention = policy['backupPolicy']['regular']['fullBackups'][0]['retention']
        if unit in frequentSchedules:
            frequency = backupSchedule[unitPath]['frequency']
            fullSchedule = 'Every %s %s keep for %s %s%s; ' % (frequency, unit, thisRetention['duration'], policy['backupPolicy']['regular']['fullBackups'][0]['retention']['unit'], dataLock)
        else:
            if unit == 'Weeks':
                fullSchedule += 'weekly on %s keep for %s %s%s; ' % ((':'.join(backupSchedule[unitPath]['dayOfWeek'])), thisRetention['duration'], thisRetention['unit'], dataLock)
            if unit == 'Months':
                if 'dayOfMonth' in backupSchedule[unitPath]:
                    fullSchedule = 'Monthly on the %s day keep for %s %s%s; ' % (backupSchedule[unitPath]['dayOfMonth'], thisRetention['duration'], thisRetention['unit'], dataLock)
                else:
                    fullSchedule += 'Monthly on %s %s keep for %s %s%s; ' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], thisRetention['duration'], thisRetention['unit'], dataLock)
            if unit == 'ProtectOnce':
                fullSchedule += 'Once keep for %s %s%s; ' % (thisRetention['duration'], thisRetention['unit'], dataLock)

    # extended retention
    if 'extendedRetention' in policy and policy['extendedRetention'] is not None and len(policy['extendedRetention']) > 0:
        for extendedRetention in policy['extendedRetention']:
            dataLock = ''
            if 'dataLockConfig' in extendedRetention['retention']:
                dataLock = ' : datalock for %s %s' % (extendedRetention['retention']['dataLockConfig']['duration'], extendedRetention['retention']['dataLockConfig']['unit'])
            if 'dataLock' in policy:
                dataLock = ' : datalock for %s %s' % (extendedRetention['retention']['duration'], extendedRetention['retention']['unit'])
            incrementalSchedule += 'Extend %s %s keep for %s %s%s; ' % (extendedRetention['schedule']['frequency'], extendedRetention['schedule']['unit'], extendedRetention['retention']['duration'], extendedRetention['retention']['unit'], dataLock)
    # log backup
    if 'log' in policy['backupPolicy']:
        logRetention = policy['backupPolicy']['log']['retention']
        backupSchedule = policy['backupPolicy']['log']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        frequency = backupSchedule[unitPath]['frequency']
        dataLock = ''
        if 'dataLockConfig' in logRetention:
            dataLock = ' : datalock for %s %s' % (logRetention['dataLockConfig']['duration'], logRetention['dataLockConfig']['unit'])
        if 'dataLock' in policy:
            dataLock = ' : datalock for %s %s' % (logRetention['duration'], logRetention['unit'])
        logSchedule = 'Every %s %s keep for %s %s%s; ' % (frequency, unit, logRetention['duration'], logRetention['unit'], dataLock)
    # remote targets
    if 'remoteTargetPolicy' in policy and policy['remoteTargetPolicy'] is not None and len(policy['remoteTargetPolicy']) > 0:
        # replication targets
        if 'replicationTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['replicationTargets'] is not None and len(policy['remoteTargetPolicy']['replicationTargets']) > 0:
            for replicationTarget in policy['remoteTargetPolicy']['replicationTargets']:
                if replicationTarget['targetType'] == 'RemoteCluster':
                    targetName = replicationTarget['remoteTargetConfig']['clusterName']
                else:
                    targetName = replicationTarget['targetType']
                frequencyunit = replicationTarget['schedule']['unit']
                if frequencyunit == 'Runs':
                    frequencyunit = 'Run'
                    frequency = 1
                else:
                    frequency = replicationTarget['schedule']['frequency']
                dataLock = ''
                if 'dataLockConfig' in replicationTarget['retention']:
                    dataLock = '; datalock for %s %s' % (replicationTarget['retention']['dataLockConfig']['duration'], replicationTarget['retention']['dataLockConfig']['unit'])
                if 'dataLock' in policy:
                    dataLock = '; datalock for %s %s' % (replicationTarget['retention']['duration'], replicationTarget['retention']['unit'])
                replicationSchedule += 'to %s every %s %s keep for %s %s%s; ' % (targetName, frequency, frequencyunit, replicationTarget['retention']['duration'], replicationTarget['retention']['unit'], dataLock)
        if 'archivalTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['archivalTargets'] is not None and len(policy['remoteTargetPolicy']['archivalTargets']) > 0:
            for archivalTarget in policy['remoteTargetPolicy']['archivalTargets']:
                frequencyunit = archivalTarget['schedule']['unit']
                if frequencyunit == 'Runs':
                    frequencyunit = 'Run'
                    frequency = 1
                else:
                    frequency = archivalTarget['schedule']['frequency']
                dataLock = ''
                if 'dataLockConfig' in archivalTarget['retention']:
                    dataLock = ' : datalock for %s %s' % (archivalTarget['retention']['dataLockConfig']['duration'], archivalTarget['retention']['dataLockConfig']['unit'])
                if 'dataLock' in policy:
                    dataLock = ' : datalock for %s %s' % (archivalTarget['retention']['duration'], archivalTarget['retention']['unit'])
                archiveSchedule += 'to %s every %s %s keep for %s %s%s; ' % (archivalTarget['targetName'], frequency, frequencyunit, archivalTarget['retention']['duration'], archivalTarget['retention']['unit'], dataLock)
    policyDetails[policy['name']] = {
        "incrementalSchedule": incrementalSchedule,
        "fullSchedule": fullSchedule,
        "logSchedule": logSchedule,
        "retries": retries,
        "replicationSchedule": replicationSchedule,
        "archiveSchedule": archiveSchedule
    }

report = []

for job in sorted(jobs['protectionGroups'], key=lambda j: j['name']):

    objects = {}

    if job['isActive'] is True:

        print('    %s' % job['name'])

        # environment type
        jobType = job['environment'][1:]
        paramsKey = [k for k in job.keys() if 'Params' in k][0]
        environmentParams = job[paramsKey]

        if 'priority' in job:
            jobPriority = job['priority'][1:]
        else:
            jobPriority = ''

        if 'sla' in job and job['sla'] is not None and len(job['sla']) > 1:
            fullSla = job['sla'][1]['slaMinutes']
            incrementalSla = job['sla'][0]['slaMinutes']
        else:
            fullSla = ''
            incrementalSla = ''

        # policy
        policy = [p for p in policies if p['id'] == job['policyId']]
        if policy is not None and len(policy) > 0:
            policy = policy[0]
            policyLink = 'https://%s/protection-policy/details/%s' % (vip, policy['id'])
        else:
            continue
        policyDetail = policyDetails[policy['name']]
        incrementalSchedule = policyDetail['incrementalSchedule']
        archiveSchedule = policyDetail['archiveSchedule']
        # cloud archive direct
        cloudArchiveDirect = False
        if 'directCloudArchive' in environmentParams and environmentParams['directCloudArchive'] is True:
            cloudArchiveDirect = True
        if 'primaryBackupTarget' in policy['backupPolicy']['regular'] and policy['backupPolicy']['regular']['primaryBackupTarget']['targetType'] == 'Archival':
            cloudArchiveDirect = True
        if cloudArchiveDirect is True:
            incrementalSchedule = ''
            archiveSchedule = policyDetail['incrementalSchedule']

        # indexing
        if 'indexingPolicy' in environmentParams and environmentParams['indexingPolicy']['enableIndexing'] is True:
            indexing = 'Enabled'
        elif 'fileProtectionTypeParams' in environmentParams and 'indexingPolicy' in environmentParams['fileProtectionTypeParams'] and environmentParams['fileProtectionTypeParams']['indexingPolicy']['enableIndexing'] is True:
            indexing = 'Enabled'
        elif 'indexingPolicy' not in environmentParams:
            indexing = 'N/A'
        else:
            indexing = 'Disabled'

        # start time
        if 'startTime' in job and 'hour' in job['startTime'] and 'minute' in job['startTime']:
            startTime = '%02d:%02d' % (job['startTime']['hour'], job['startTime']['minute'])
        else:
            startTime = 'N/A'

        # timezone
        if 'startTime' in job and 'timeZone' in job['startTime']:
            timeZone = job['startTime']['timeZone']
        else:
            timeZone = ''

        # runs
        runs = api('get', 'data-protect/protection-groups/%s/runs?includeObjectDetails=true&numRuns=7' % job['id'], v=2)
        if len(runs['runs']) > 0:
            try:
                runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs'] if r['localBackupInfo']['runType'] == 'kLog']
                if len(runDates) == 0:
                    runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs']]
            except Exception:
                runDates = [r['archivalInfo']['archivalTargetResults'][0]['startTimeUsecs'] for r in runs['runs']]
            
            # status
            try:
                lastStatus = runs['runs'][0]['localBackupInfo']['status']
            except Exception:
                lastStatus = runs['runs'][0]['archivalInfo']['archivalTargetResults'][0]['status']

            # QoS Policy
            qosPolicy = '-'
            if 'qosPolicy' in job:
                qosPolicy = job['qosPolicy'][1:]

            for run in runs['runs']:
                if 'localBackupInfo' in run:
                    runInfo = run['localBackupInfo']
                else:
                    runInfo = run['archivalInfo']['archivalTargetResults'][0]
                
                for item in run['objects']:
                    object = item['object']
                    # try:
                    if 'localSnapshotInfo' in item:
                        itemInfo = item['localSnapshotInfo']['snapshotInfo']
                        lastStatus = itemInfo['status'][1:]
                    else:
                        itemInfo = item['archivalInfo']['archivalTargetResults'][0]
                        lastStatus = itemInfo['status']
                    # logical size
                    if 'logicalSizeBytes' in itemInfo['stats']:
                        objectMiB = int(itemInfo['stats']['logicalSizeBytes'] / (1024 * 1024))
                    else:
                        objectMiB = 0

                    if object['id'] not in objects.keys():
                        objects[object['id']] = {
                            'name': object['name'],
                            'id': object['id'],
                            'objectType': object['objectType'],
                            'objectMiB': objectMiB,
                            'environment': object['environment'],
                            'cloudArchiveDirect': cloudArchiveDirect,
                            'jobName': job['name'],
                            'policyName': policy['name'],
                            'jobEnvironment': job['environment'],
                            'runDates': runDates,
                            'sourceId': '',
                            'parent': '',
                            'lastStatus': lastStatus,
                            'lastRunType': runInfo['runType'][1:],
                            'jobPaused': job['isPaused'],
                            'indexing': indexing,
                            'startTime': startTime,
                            'timeZone': timeZone,
                            'qosPolicy': qosPolicy,
                            'priority': jobPriority,
                            'fullSla': fullSla,
                            'incrementalSla': incrementalSla,
                            "incrementalSchedule": incrementalSchedule,
                            "fullSchedule": policyDetail['fullSchedule'],
                            "logSchedule": policyDetail['logSchedule'],
                            "retries": policyDetail['retries'],
                            "replicationSchedule": policyDetail['replicationSchedule'],
                            "archiveSchedule": archiveSchedule
                        }
                    else:
                        if objects[object['id']]['objectMiB'] == 0:
                            objects[object['id']]['objectMiB'] = objectMiB
                    if 'sourceId' in object:
                        objects[object['id']]['sourceId'] = object['sourceId']
                    # except Exception:
                    #     pass

    for id in objects.keys():
        object = objects[id]

        # parent
        parent = None
        parentName = '-'
        if object['sourceId'] != '':
            parent = [s for s in sources if s['protectionSource']['id'] == object['sourceId']]

            if object['sourceId'] in objects.keys():
                parent = objects[object['sourceId']]
                parentName = parent['name']
            else:
                parent = [s for s in sources if s['protectionSource']['id'] == object['sourceId']]
                if len(parent) > 0:
                    parentName = parent[0]['protectionSource']['name']

        if parent is not None or object['environment'] == object['jobEnvironment']:
            if parentName == '-':
                parentName = object['name']
            object['parent'] = parentName.replace(',', ';')
            # last run date
            lastRunDate = usecsToDate(object['runDates'][0])

            report.append(str('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' % (cluster['name'],
                                                                                                                 object['jobName'],
                                                                                                                 object['environment'][1:],
                                                                                                                 object['parent'],
                                                                                                                 object['name'],
                                                                                                                 object['objectType'][1:],
                                                                                                                 object['objectMiB'],
                                                                                                                 object['policyName'],
                                                                                                                 object['cloudArchiveDirect'],
                                                                                                                 lastRunDate,
                                                                                                                 object['lastStatus'],
                                                                                                                 object['lastRunType'],
                                                                                                                 object['jobPaused'],
                                                                                                                 object['indexing'],
                                                                                                                 object['startTime'],
                                                                                                                 object['timeZone'],
                                                                                                                 object['qosPolicy'],
                                                                                                                 object['priority'],
                                                                                                                 object['fullSla'],
                                                                                                                 object['incrementalSla'],
                                                                                                                 object['incrementalSchedule'],
                                                                                                                 object['fullSchedule'],
                                                                                                                 object['logSchedule'],
                                                                                                                 object['retries'],
                                                                                                                 object['replicationSchedule'],
                                                                                                                 object['archiveSchedule'])))

for item in sorted(report):
    f.write('%s\n' % item)

f.close()
print('\nOutput saved to %s\n' % outfile)
