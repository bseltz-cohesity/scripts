#!/usr/bin/env python
"""List Protected Objects for python"""

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
parser.add_argument('-db', '--showdbs', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
showdbs = args.showdbs

# authenticate
apiauth(vip, username, domain)

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
jobs = api('get', 'data-protect/protection-groups', v=2)

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

        # cloud archive direct
        cloudArchiveDirect = False
        if 'directCloudArchive' in environmentParams and environmentParams['directCloudArchive'] is True:
            cloudArchiveDirect = True

        # policy
        policy = [p for p in policies if p['id'] == job['policyId']][0]
        policyLink = 'https://%s/protection-policy/details/%s' % (vip, policy['id'])

        # archive target
        archiveTarget = '-'
        if 'remoteTargetPolicy' in policy:
            if 'archivalTargets' in policy['remoteTargetPolicy'] and len(policy['remoteTargetPolicy']['archivalTargets']) > 0:
                archiveTarget = policy['remoteTargetPolicy']['archivalTargets'][0]['targetName']

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
        if 'startTime' in job and 'hour' in job['startTime']:
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
            runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs'] if r['localBackupInfo']['runType'] == 'kLog']
            if len(runDates) == 0:
                runDates = [r['localBackupInfo']['startTimeUsecs'] for r in runs['runs']]

            # status
            lastStatus = runs['runs'][0]['localBackupInfo']['status']

            # QoS Policy
            qosPolicy = '-'
            if 'qosPolicy' in job:
                qosPolicy = job['qosPolicy'][1:]

            for run in runs['runs']:
                for item in run['objects']:
                    object = item['object']

                    # logical size
                    if 'logicalSizeBytes' in item['localSnapshotInfo']['snapshotInfo']['stats']:
                        objectMiB = int(item['localSnapshotInfo']['snapshotInfo']['stats']['logicalSizeBytes'] / (1024 * 1024))
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
                            'lastRunType': run['localBackupInfo']['runType'][1:],
                            'jobPaused': job['isPaused'],
                            'indexing': indexing,
                            'startTime': startTime,
                            'timeZone': timeZone,
                            'policyLink': policyLink,
                            'qosPolicy': qosPolicy,
                            'priority': job['priority'][1:],
                            'fullSla': job['sla'][1]['slaMinutes'],
                            'incrementalSla': job['sla'][0]['slaMinutes'],
                            'archiveTarget': archiveTarget
                        }
                    else:
                        if objects[object['id']]['objectMiB'] == 0:
                            objects[object['id']]['objectMiB'] = objectMiB
                    if 'sourceId' in object:
                        objects[object['id']]['sourceId'] = object['sourceId']

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
