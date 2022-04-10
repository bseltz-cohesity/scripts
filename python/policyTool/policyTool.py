#!/usr/bin/env python
"""Manage Protection Policy Using Python"""

# version 2022.04.10

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-f', '--frequency', type=int, default=None)
parser.add_argument('-fu', '--frequencyunit', type=str, choices=['runs', 'minutes', 'hours', 'days', 'weeks', 'months', 'years'], default='runs')
parser.add_argument('-r', '--retention', type=int, default=None)
parser.add_argument('-ru', '--retentionunit', type=str, choices=['days', 'weeks', 'months', 'years'], default='days')
parser.add_argument('-a', '--action', type=str, choices=['list', 'addreplica', 'deletereplica', 'addarchive', 'deletearchive'], default='list')
parser.add_argument('-n', '--targetname', type=str, default=None)
parser.add_argument('-all', '--all', action='store_true')
args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
policyname = args.policyname          # name of policy to focus on
frequency = args.frequency            # number of frequency units for schedule
frequencyunit = args.frequencyunit    # frequency units for schedule
retention = args.retention            # number of retention units
retentionunit = args.retentionunit    # retention units
action = args.action                  # action to perform
targetname = args.targetname          # name of remote cluster or external target
alltargets = args.all                 # delete all entries for the specified target

if frequencyunit != 'runs' and frequency is None:
    frequency = 1

if frequencyunit == 'runs' and frequency is not None:
    frequencyunit = 'days'

frequentSchedules = ['Minutes', 'Hours', 'Days']

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

policies = sorted((api('get', 'data-protect/policies', v=2))['policies'], key=lambda policy: policy['name'].lower())

if policyname is not None:
    policies = [p for p in policies if p['name'].lower() == policyname.lower()]
    if policies is None or len(policies) == 0:
        print("Policy '%s' not found!" % policyname)
        exit(1)
else:
    if action != 'list':
        print('--policyname required')
        exit()

# add replica
if action == 'addreplica':
    if targetname is None:
        print('--targetname required')
        exit()
    if retention is None:
        print('--retention rewquired')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
    remoteClusters = api('get', 'remoteClusters')
    thisRemoteCluster = [r for r in remoteClusters if r['name'].lower() == targetname.lower()]
    if thisRemoteCluster is None or len(thisRemoteCluster) == 0:
        print('Remote cluster %s not found' % targetname)
        exit()
    thisRemoteCluster = thisRemoteCluster[0]
    policy = policies[0]
    if 'remoteTargetPolicy' not in policy:
        policy['remoteTargetPolicy'] = {}
    if 'replicationTargets' not in policy['remoteTargetPolicy']:
        policy['remoteTargetPolicy']['replicationTargets'] = []
    # find existing replica
    existingReplica = [r for r in policy['remoteTargetPolicy']['replicationTargets'] if r['targetType'] == 'RemoteCluster' and r['remoteTargetConfig']['clusterName'].lower() == targetname.lower() and r['schedule']['unit'].lower() == frequencyunit.lower() and ('frequency' not in r['schedule'] or r['schedule']['frequency'] == frequency)]
    if existingReplica is None or len(existingReplica) == 0:
        newReplica = {
            "schedule": {
                "unit": frequencyunit.title()
            },
            "retention": {
                "unit": retentionunit.title(),
                "duration": retention
            },
            "copyOnRunSuccess": False,
            "targetType": "RemoteCluster",
            "remoteTargetConfig": {
                "clusterId": thisRemoteCluster['clusterId'],
                "clusterName": thisRemoteCluster['name']
            }
        }
        if frequencyunit != 'runs':
            newReplica['schedule']['frequency'] = frequency
        policy['remoteTargetPolicy']['replicationTargets'].append(newReplica)
    else:
        existingReplica[0]['retention']['unit'] = retentionunit.title()
        existingReplica[0]['retention']['duration'] = retention
    result = api('put', 'data-protect/policies/%s' % policy['id'], policy, v=2)

# delete replica
if action == 'deletereplica':
    if targetname is None:
        print('--targetname required')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
    # find existing replica
    policy = policies[0]
    if 'remoteTargetPolicy' in policy and 'replicationTargets' in policy['remoteTargetPolicy']:
        newReplicationTargets = []
        changedReplicationTargets = False
        for replicationTarget in policy['remoteTargetPolicy']['replicationTargets']:
            includeThisReplica = True
            if replicationTarget['targetType'] == 'RemoteCluster' and replicationTarget['remoteTargetConfig']['clusterName'].lower() == targetname.lower():
                if alltargets:
                    includeThisReplica = False
                else:
                    if replicationTarget['schedule']['unit'].lower() == frequencyunit.lower() and ('frequency' not in replicationTarget['schedule'] or replicationTarget['schedule']['frequency'] == frequency):
                        includeThisReplica = False
            if includeThisReplica is True:
                newReplicationTargets.append(replicationTarget)
            else:
                changedReplicationTargets = True
        if changedReplicationTargets is True:
            policy['remoteTargetPolicy']['replicationTargets'] = newReplicationTargets
            result = api('put', 'data-protect/policies/%s' % policy['id'], policy, v=2)

# add archive
if action == 'addarchive':
    if targetname is None:
        print('--targetname required')
        exit()
    if retention is None:
        print('--retention rewquired')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
    vaults = api('get', 'vaults')
    thisVault = [v for v in vaults if v['name'].lower() == targetname.lower()]
    if thisVault is None or len(thisVault) == 0:
        print('External target %s not found' % targetname)
        exit()
    thisVault = thisVault[0]
    policy = policies[0]
    if 'remoteTargetPolicy' not in policy:
        policy['remoteTargetPolicy'] = {}
    if 'archivalTargets' not in policy['remoteTargetPolicy']:
        policy['remoteTargetPolicy']['archivalTargets'] = []
    # find existing replica
    existingTarget = [t for t in policy['remoteTargetPolicy']['archivalTargets'] if t['targetId'] == thisVault['id']]
    if existingTarget is None or len(existingTarget) == 0:
        newTarget = {
            "schedule": {
                "unit": frequencyunit.title()
            },
            "retention": {
                "unit": retentionunit.title(),
                "duration": retention
            },
            "copyOnRunSuccess": False,
            "targetId": thisVault['id'],
            "targetName": thisVault['name'],
            "targetType": "Cloud"
        }
        if frequencyunit != 'runs':
            newTarget['schedule']['frequency'] = frequency
        policy['remoteTargetPolicy']['archivalTargets'].append(newTarget)
    else:
        existingTarget[0]['retention']['unit'] = retentionunit.title()
        existingTarget[0]['retention']['duration'] = retention
    result = api('put', 'data-protect/policies/%s' % policy['id'], policy, v=2)

# delete archive
if action == 'deletearchive':
    if targetname is None:
        print('--targetname required')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
    # find existing replica
    policy = policies[0]
    if 'remoteTargetPolicy' in policy and 'archivalTargets' in policy['remoteTargetPolicy']:
        newArchivalTargets = []
        changedArchivalTargets = False
        for archiveTarget in policy['remoteTargetPolicy']['archivalTargets']:
            includeThisArchive = True
            if archiveTarget['targetName'].lower() == targetname.lower():
                includeThisArchive = False
            if includeThisArchive is True:
                newArchivalTargets.append(archiveTarget)
            else:
                changedArchiveTargets = True
        if changedArchiveTargets is True:
            policy['remoteTargetPolicy']['archivalTargets'] = newArchivalTargets
            result = api('put', 'data-protect/policies/%s' % policy['id'], policy, v=2)

# list policies
for policy in policies:
    print('\n%s' % policy['name'])
    print(('-' * len(policy['name']) + '\n'))
    # base retention
    baseRetention = policy['backupPolicy']['regular']['retention']
    dataLock = ''
    if 'dataLockConfig' in baseRetention and baseRetention['dataLockConfig'] is not None:
        dataLock = ', datalock for %s %s' % (baseRetention['dataLockConfig']['duration'], baseRetention['dataLockConfig']['unit'])
    if 'dataLock' in policy:
        dataLock = ', datalock for %s %s' % (baseRetention['duration'], baseRetention['unit'])
    # incremental backup
    if 'incremental' in policy['backupPolicy']['regular']:
        backupSchedule = policy['backupPolicy']['regular']['incremental']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        if unit in frequentSchedules:
            frequency = backupSchedule[unitPath]['frequency']
            print('  Incremental backup:  Every %s %s  (keep for %s %s%s)' % (frequency, unit, baseRetention['duration'], baseRetention['unit'], dataLock))
        else:
            if unit == 'Weeks':
                print('  Incremental backup:  Weekly on %s  (keep for %s %s%s)' % ((', '.join(backupSchedule[unitPath]['dayOfWeek'])), baseRetention['duration'], baseRetention['unit'], dataLock))
            if unit == 'Months':
                print('  Incremental backup:  Monthly on the %s %s  (keep for %s %s%s)' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], baseRetention['duration'], baseRetention['unit'], dataLock))
    # full backup
    if 'full' in policy['backupPolicy']['regular']:
        backupSchedule = policy['backupPolicy']['regular']['full']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        if unit in frequentSchedules:
            frequency = backupSchedule[unitPath]['frequency']
            print('         Full backup:  Every %s %s  (keep for %s %s' % (frequency, unit, baseRetention['duration'], baseRetention['unit']))
        else:
            if unit == 'Weeks':
                print('         Full backup:  Weekly on %s  (keep for %s %s)' % ((', '.join(backupSchedule[unitPath]['dayOfWeek'])), baseRetention['duration'], baseRetention['unit']))
            if unit == 'Months':
                print('         Full backup:  Monthly on the %s %s  (keep for %s %s)' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], baseRetention['duration'], baseRetention['unit']))
            if unit == 'ProtectOnce':
                print('         Full backup:  Once (keep for %s %s)' % (baseRetention['duration'], baseRetention['unit']))
    # extended retention
    if 'extendedRetention' in policy and policy['extendedRetention'] is not None and len(policy['extendedRetention']) > 0:
        print('  Extended retention:')
        for extendedRetention in policy['extendedRetention']:
            print('                       Every %s %s  (keep for %s %s)' % (extendedRetention['schedule']['frequency'], extendedRetention['schedule']['unit'], extendedRetention['retention']['duration'], extendedRetention['retention']['unit']))
    # log backup
    if 'log' in policy['backupPolicy']:
        logRetention = policy['backupPolicy']['log']['retention']
        backupSchedule = policy['backupPolicy']['log']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        frequency = backupSchedule[unitPath]['frequency']
        print('          Log backup:  Every %s %s  (keep for %s %s)' % (frequency, unit, baseRetention['duration'], baseRetention['unit']))
    # remote targets
    if 'remoteTargetPolicy' in policy and policy['remoteTargetPolicy'] is not None and len(policy['remoteTargetPolicy']) > 0:
        # replication targets
        if 'replicationTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['replicationTargets'] is not None and len(policy['remoteTargetPolicy']['replicationTargets']) > 0:
            print('        Replicate To:')
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
                print('                       %s:  Every %s %s  (keep for %s %s)' % (targetName, frequency, frequencyunit, replicationTarget['retention']['duration'], replicationTarget['retention']['unit']))
        if 'archivalTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['archivalTargets'] is not None and len(policy['remoteTargetPolicy']['archivalTargets']) > 0:
            print('          Archive To:')
            for archivalTarget in policy['remoteTargetPolicy']['archivalTargets']:
                frequencyunit = archivalTarget['schedule']['unit']
                if frequencyunit == 'Runs':
                    frequencyunit = 'Run'
                    frequency = 1
                else:
                    frequency = archivalTarget['schedule']['frequency']
                print('                       %s:  Every %s %s  (keep for %s %s)' % (archivalTarget['targetName'], frequency, frequencyunit, archivalTarget['retention']['duration'], archivalTarget['retention']['unit']))
    print('')
