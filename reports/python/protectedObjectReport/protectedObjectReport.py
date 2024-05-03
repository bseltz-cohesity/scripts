#!/usr/bin/env python
"""List Protected Objects 2021-12-11 for python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # username
parser.add_argument('-d', '--domain', type=str, default='local')  # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-o', '--objectname', action='append', type=str)
parser.add_argument('-l', '--objectlist', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
objectnames = args.objectname
objectlist = args.objectlist


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


objectnames = gatherList(objectnames, objectlist, name='objects', required=False)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')

print('\nGathering Job Info from %s...\n' % cluster['name'])

# outfile
now = datetime.now()
dateString = now.strftime("%Y-%m-%d")
outfile = 'protectedObjectReport-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# gather info
sources = api('get', 'protectionSources?includeVMFolders=true')
policies = api('get', 'data-protect/policies', v=2)['policies']
jobs = api('get', 'data-protect/protection-groups?includeTenants=true', v=2)

# headings
f.write('Cluster Name,Job Name,Environment,Object Name,Object Type,Object Size (MiB),Parent,Policy Name,Policy Link,Archive Target,Direct Archive,Frequency (Minutes),Last Backup,Last Status,Last Run Type,Job Paused,Indexed,Start Time,Time Zone,QoS Policy,Priority,Full SLA,Incremental SLA\n')

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

        fullSla = ''
        incrementalSla = ''
        try:
            fullSla = job['sla'][1]['slaMinutes']
        except Exception:
            pass
        try:
            incrementalSla = job['sla'][0]['slaMinutes']
        except Exception:
            pass

        # cloud archive direct
        cloudArchiveDirect = False
        if 'directCloudArchive' in environmentParams and environmentParams['directCloudArchive'] is True:
            cloudArchiveDirect = True

        # policy
        policy = [p for p in policies if p['id'] == job['policyId']]

        if policy is not None and len(policy) > 0:
            policy = policy[0]
            policyLink = 'https://%s/protection-policy/details/%s' % (vip, policy['id'])
        else:
            continue
        # archive target
        archiveTarget = '-'
        if 'remoteTargetPolicy' in policy:
            if 'archivalTargets' in policy['remoteTargetPolicy'] and len(policy['remoteTargetPolicy']['archivalTargets']) > 0:
                archiveTarget = policy['remoteTargetPolicy']['archivalTargets'][0]['targetName']
        if 'backupPolicy in policy':
            if 'regular' in policy['backupPolicy'] and 'primaryBackupTarget' in policy['backupPolicy']['regular'] and policy['backupPolicy']['regular']['primaryBackupTarget']['targetType'] == 'Archival':
                archiveTarget = policy['backupPolicy']['regular']['primaryBackupTarget']['archivalTargetSettings']['targetName']
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
            isCad = False
            if 'localBackupInfo' in runs['runs'][0]:
                runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs'] if r['localBackupInfo']['runType'] == 'kLog']
                if len(runDates) == 0:
                    runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs']]
                lastStatus = runs['runs'][0]['localBackupInfo']['status']
            else:
                isCad = True
                runDates = [r['archivalInfo']['archivalTargetResults'][0]['startTimeUsecs'] for r in runs['runs'] if r['archivalInfo']['archivalTargetResults'][0]['runType'] == 'kLog']
                if len(runDates) == 0:
                    runDates = [r['archivalInfo']['archivalTargetResults'][0]['startTimeUsecs'] for r in runs['runs']]
                lastStatus = runs['runs'][0]['archivalInfo']['archivalTargetResults'][0]['status']

            # QoS Policy
            qosPolicy = '-'
            if 'qosPolicy' in job:
                qosPolicy = job['qosPolicy'][1:]

            for run in runs['runs']:
                if isCad is False:
                    runInfo = run['localBackupInfo']
                else:
                    runInfo = run['archivalInfo']['archivalTargetResults'][0]
                for item in run['objects']:
                    object = item['object']
                    try:
                        if isCad is False:
                            snapInfo = item['localSnapshotInfo']['snapshotInfo']
                            lastStatus = snapInfo['status'][1:]
                        else:
                            snapInfo = item['archivalInfo']['archivalTargetResults'][0]
                            lastStatus = snapInfo['status']
                        # logical size
                        if 'logicalSizeBytes' in snapInfo['stats']:
                            objectMiB = int(snapInfo['stats']['logicalSizeBytes'] / (1024 * 1024))
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
                                'policyLink': policyLink,
                                'qosPolicy': qosPolicy,
                                'priority': jobPriority,
                                'fullSla': fullSla,
                                'incrementalSla': incrementalSla,
                                'archiveTarget': archiveTarget
                            }
                        else:
                            if objects[object['id']]['objectMiB'] == 0:
                                objects[object['id']]['objectMiB'] = objectMiB
                        if 'sourceId' in object:
                            objects[object['id']]['sourceId'] = object['sourceId']
                    except Exception:
                        pass

    for id in objects.keys():
        object = objects[id]
        if len(objectnames) == 0 or object['name'].lower() in [o.lower() for o in objectnames]:
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
                object['parent'] = parentName

                # frequency
                if len(object['runDates']) > 1 and object['jobPaused'] is not True:
                    frequency = int(round((object['runDates'][0] - object['runDates'][-1]) / (len(object['runDates']) - 1) / (1000000 * 60)))  # [math]::Round((($object.runDates[0] - $object.runDates[-1]) / ($object.runDates.count - 1)) / (1000000 * 60))
                else:
                    frequency = '-'

                # last run date
                lastRunDate = usecsToDate(object['runDates'][0])

                report.append(str('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' % (cluster['name'], object['jobName'], object['environment'][1:], object['name'], object['objectType'][1:], object['objectMiB'], object['parent'], object['policyName'], object['policyLink'], object['archiveTarget'], object['cloudArchiveDirect'], frequency, lastRunDate, object['lastStatus'], object['lastRunType'], object['jobPaused'], object['indexing'], object['startTime'], object['timeZone'], object['qosPolicy'], object['priority'], object['fullSla'], object['incrementalSla'])))

for item in sorted(report):
    f.write('%s\n' % item)

f.close()
print('\nOutput saved to %s\n' % outfile)
