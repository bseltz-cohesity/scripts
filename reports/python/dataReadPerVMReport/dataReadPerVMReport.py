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
parser.add_argument('-y', '--days', type=int, default=30)
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
days = args.days
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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
daysAgoUsecs = timeAgo(days, 'days')
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/storagePerVMReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Job Name","Source Name","Object Name","%s Read","%s Read (adjuested)","%s Written","Job Reduction Ratio"\n' % (units, units, units))


if skipdeleted:
    jobs = api('get', 'data-protect/protection-groups?environments=kVMware&isActive=true&isDeleted=false&includeTenants=true&startTimeUsecs=%s' % daysAgoUsecs, v=2)
else:
    jobs = api('get', 'data-protect/protection-groups?environments=kVMware&isActive=true&includeTenants=true&startTimeUsecs=%s' % daysAgoUsecs, v=2)

storageDomains = api('get', 'viewBoxes')

sourceNames = {}
for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if job['environment'] not in ['kView', 'kRemoteAdapter']:

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

        # get jobReduction factor
        if job['isActive'] is True:
            stats = api('get', 'stats/consumers?consumerType=kProtectionRuns&consumerIdList=%s' % v1JobId)
        else:
            stats = api('get', 'stats/consumers?consumerType=kReplicationRuns&consumerIdList=%s' % v1JobId)
        if 'statsList' in stats and stats['statsList'] is not None:
            dataIn = stats['statsList'][0]['stats'].get('dataInBytes', 0)
            dataInAfterDedup = stats['statsList'][0]['stats'].get('dataInBytesAfterDedup', 0)
            jobWritten = stats['statsList'][0]['stats'].get('dataWrittenBytes', 0)
            storageConsumedBytes = stats['statsList'][0]['stats'].get('storageConsumedBytes', 0)
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
            if endUsecs < daysAgoUsecs:
                break
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
                            if snap['snapshotInfo']['startTimeUsecs'] < daysAgoUsecs:
                                break
                            try:
                                if objId not in objects:
                                    objects[objId] = {}
                                    objects[objId]['name'] = object['object']['name']
                                    objects[objId]['bytesWritten'] = 0
                                    objects[objId]['bytesRead'] = 0
                                    if 'sourceId' in object['object']:
                                        objects[objId]['sourceId'] = object['object']['sourceId']
                                objects[objId]['bytesWritten'] += snap['snapshotInfo']['stats']['bytesWritten']
                                objects[objId]['bytesRead'] += snap['snapshotInfo']['stats']['bytesRead']
                            except Exception as e:
                                pass

        for object in sorted(objects.keys()):
            thisObject = objects[object]
            if 'bytesRead' in thisObject and 'bytesWritten' in thisObject:
                adjustedDataRead = round(thisObject['bytesWritten'] * jobReduction / multiplier, 1)
                dataRead = round(thisObject['bytesRead'] / multiplier, 1)
                dataWritten = round(thisObject['bytesWritten'] / multiplier, 1)
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
                csv.write('"%s","%s","%s","%s","%s","%s","%s"\n' % (job['name'], sourceName, thisObject['name'], dataRead, adjustedDataRead, dataWritten, jobReduction))

csv.close()
print('\nOutput saved to %s\n' % csvfileName)
