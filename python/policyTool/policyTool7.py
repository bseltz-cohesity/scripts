#!/usr/bin/env python
"""Manage Protection Policy Using Python"""

# version 2024.08.06

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
parser.add_argument('-ld', '--lockduration', type=int, default=None)
parser.add_argument('-lu', '--lockunit', type=str, choices=['days', 'weeks', 'months', 'years'], default='days')
parser.add_argument('-ru', '--retentionunit', type=str, choices=['days', 'weeks', 'months', 'years'], default='days')
parser.add_argument('-a', '--action', type=str, choices=['list', 'create', 'edit', 'delete', 'addfull', 'deletefull', 'addextension', 'deleteextension', 'logbackup', 'addreplica', 'deletereplica', 'addarchive', 'deletearchive', 'editretries'], default='list')
parser.add_argument('-n', '--targetname', type=str, default=None)
parser.add_argument('-all', '--all', action='store_true')
parser.add_argument('-t', '--retries', type=int, default=3)
parser.add_argument('-m', '--retryminutes', type=int, default=5)
parser.add_argument('-aq', '--addquiettime', action='append', type=str)
parser.add_argument('-rq', '--removequiettime', action='append', type=str)
parser.add_argument('-dow', '--dayofweek', action='append', type=str, choices=['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'])
parser.add_argument('-wom', '--weekofmonth', type=str, choices=['First', 'Second', 'Third', 'Fourth', 'Last', 'first', 'second', 'third', 'fourth', 'last'], default='First')
parser.add_argument('-dom', '--dayofmonth', type=int, default=1)
parser.add_argument('-doy', '--dayofyear', type=str, choices=['First', 'Last', 'first', 'last'], default='First')

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
lockduration = args.lockduration      # number of lock units
lockunit = args.lockunit              # lock units
action = args.action                  # action to perform
targetname = args.targetname          # name of remote cluster or external target
allfortarget = args.all               # delete all entries for the specified target
retries = args.retries                # number of retries
retryminutes = args.retryminutes      # number of minutes to wait between retries
addquiettime = args.addquiettime      # add quiet time
removequiettime = args.removequiettime  # remove quiettime
dayofweek = args.dayofweek
weekofmonth = args.weekofmonth
dayofmonth = args.dayofmonth
dayofyear = args.dayofyear

if frequencyunit != 'runs' and frequency is None:
    frequency = 1

if frequencyunit == 'runs' and frequency is not None:
    if action == 'logbackup':
        frequencyunit = 'hours'
    else:
        frequencyunit = 'days'

frequentSchedules = ['Minutes', 'Hours', 'Days']

if addquiettime is None:
    addquiettime = []
if removequiettime is None:
    removequiettime = []


def makeSchedule(cbs=True):
    global frequencyunit
    global frequency
    global dayofweek
    global dayofmonth
    global dayofyear
    global weekofmonth

    thisSchedule = {
        "unit": frequencyunit.title()
    }
    if cbs is True:
        if frequencyunit == 'days':
            thisSchedule['daySchedule'] = {
                "frequency": frequency
            }
        if frequencyunit == 'hours':
            thisSchedule['hourSchedule'] = {
                "frequency": frequency
            }
        if frequencyunit == 'minutes':
            thisSchedule['minuteSchedule'] = {
                "frequency": frequency
            }
        if frequencyunit == 'weeks':
            if dayofweek is None or len(dayofweek) == 0:
                dayofweek = ['Sunday']
            thisSchedule['weekSchedule'] = {
                "dayOfWeek": [d.title() for d in dayofweek]
            }
        if frequencyunit == 'months':
            if dayofweek is not None and len(dayofweek) > 0:
                thisSchedule = {
                    "monthSchedule": {
                        "dayOfWeek": [d.title() for d in dayofweek],
                        "weekOfMonth": weekofmonth.title()
                    }, 
                    "unit": "Months"
                }
            else:
                thisSchedule = {
                    "monthSchedule": {
                        "dayOfMonth": dayofmonth, 
                        "dayOfWeek": None
                    }, 
                    "unit": "Months"
                }
        if frequencyunit == 'years':
            thisSchedule = {
                "unit": "Years", 
                "yearSchedule": {
                    "dayOfYear": dayofyear.title()
                }
            }
    else:
        thisSchedule['frequency'] = frequency

    return thisSchedule


def makeRetention():
    global retentionunit
    global retention
    global lockunit
    global lockduration
    thisRetention = {
        "unit": retentionunit.title(),
        "duration": retention
    }
    if lockduration is not None:
        thisRetention['dataLockConfig'] = {
            "mode": "Compliance",
            "unit": lockunit.title(),
            "duration": lockduration
        }
    return thisRetention


def parseTime(thistime, description='time'):
    try:
        (hour, minute) = thistime.split(':')
        hour = int(hour)
        minute = int(minute)
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            print('%s is invalid!' % description)
            exit(1)
        return [hour, minute]
    except Exception:
        print('%s is invalid!' % description)
        exit(1)


# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

policy = None
policies = sorted((api('get', 'data-protect/policies', v=2))['policies'], key=lambda policy: policy['name'].lower())
cluster = api('get', 'cluster')
if cluster['clusterSoftwareVersion'] < '7.1':
    print('this script requires Cohesity version 7.1 or higher')
    exit()

if policyname is not None:
    policies = [p for p in policies if p['name'].lower() == policyname.lower()]
    if policies is None or len(policies) == 0:
        if action != 'create':
            print("Policy '%s' not found!" % policyname)
            exit()
    else:
        policy = policies[0]
        policies = [policy]
        if action == 'create':
            print("Policy '%s' already exists" % policyname)
            action = 'list'
else:
    if action != 'list':
        print('--policyname required')
        exit()

# create new policy
if action == 'create':
    if retention is None:
        print('--retention is required')
        exit()
    if frequency is None:
        frequency = 1
    if frequencyunit == 'runs':
        frequencyunit = 'days'

    policy = {
        "backupPolicy": {
            "regular": {
                "incremental": {
                    "schedule": makeSchedule()
                },
                "retention": makeRetention()
            }
        },
        "id": None,
        "name": policyname,
        "description": None,
        "remoteTargetPolicy": {},
        "isCBSEnabled": True,
        "retryOptions": {
            "retries": retries,
            "retryIntervalMins": retryminutes
        }
    }
    result = api('post', 'data-protect/policies', policy, v=2)
    policies = [policy]

if action == 'delete':
    print('Deleting policy %s' % policy['name'])
    result = api('delete', 'data-protect/policies/%s' % policy['id'], v=2)
    exit()

updatePolicy = False
if policy is not None:
    if action not in ['create', 'list'] or len(addquiettime) > 0 or len(removequiettime) > 0:
        updatePolicy = True
    policy['isCBSEnabled'] = True
    if lockduration is None and 'dataLockConfig' in policy['backupPolicy']['regular']['retention']:
        lockduration = policy['backupPolicy']['regular']['retention']['dataLockConfig']['duration']
        lockunit = policy['backupPolicy']['regular']['retention']['dataLockConfig']['unit']


# edit policy
if action == 'edit':
    if retention is None:
        print('--retention is required')
        exit()
    if frequency is None:
        frequency = 1
    if frequencyunit == 'runs':
        frequencyunit = 'days'

    policy['backupPolicy']['regular']['incremental']['schedule'] = makeSchedule()
    policy['backupPolicy']['regular']['retention'] = makeRetention()

# edit retry settings
if action == 'editretries':
    policy['retryOptions']['retries'] = retries
    policy['retryOptions']['retryIntervalMins'] = retryminutes

# delete full backup

if action == 'deletefull':
    if 'fullBackups' in policy['backupPolicy']['regular'] and policy['backupPolicy']['regular']['fullBackups'] is not None and len(policy['backupPolicy']['regular']['fullBackups']) > 0:
        policy['isCBSEnabled'] = True
        policy['backupPolicy']['regular']['fullBackups'] = [f for f in policy['backupPolicy']['regular']['fullBackups'] if f['schedule']['unit'] != frequencyunit.title()]

# add full backup
if action == 'addfull':
    policy['isCBSEnabled'] = True
    if retention is None:
        print('--retention is required')
        exit()
    if frequency is None:
        frequency = 1
    if frequencyunit == 'runs':
        frequencyunit = 'days'

    if 'fullBackups' not in policy['backupPolicy']['regular'] or policy['backupPolicy']['regular']['fullBackups'] is None:
        policy['backupPolicy']['regular']['fullBackups'] = []
    
    scheduleName = "%sSchedule" % frequencyunit[0:len(frequencyunit) - 1]
    policy['backupPolicy']['regular']['fullBackups'] = [f for f in policy['backupPolicy']['regular']['fullBackups'] if scheduleName not in f['schedule']]
    fullBackup = {
        "schedule": makeSchedule(),
        "retention": makeRetention()
    }   
    policy['backupPolicy']['regular']['fullBackups'].append(fullBackup)

# add extend retention
if action == 'addextension':
    if retention is None:
        print('--retention is required')
        exit()
    if frequency is None:
        frequency = 1
    if frequencyunit == 'runs':
        frequencyunit = 'days'
    if 'extendedRetention' not in policy or policy['extendedRetention'] is None:
        policy['extendedRetention'] = []
        existingRetention = None
    else:
        existingRetention = [r for r in policy['extendedRetention'] if r['schedule']['unit'].lower() == frequencyunit and r['schedule']['frequency'] == frequency]
    if existingRetention is None or len(existingRetention) == 0:
        newRetention = {
            "schedule": makeSchedule(False)
        }
        policy['extendedRetention'].append(newRetention)
    else:
        existingRetention[0]['retention'] = makeRetention()

# delete extended retention
if action == 'deleteextension':
    if 'extendedRetention' in policy and policy['extendedRetention'] is not None:
        newRetentions = []
        for existingRetention in policy['extendedRetention']:
            includeRetention = True
            if existingRetention['schedule']['unit'].lower() == frequencyunit and existingRetention['schedule']['frequency'] == frequency:
                includeRetention = False
            if includeRetention:
                newRetentions.append(existingRetention)
        policy['extendedRetention'] = newRetentions

# log backup
if action == 'logbackup':
    if retention is None:
        print('--retention is required')
        exit()
    if frequency is None:
        frequency = 1
    if frequencyunit == 'runs':
        frequencyunit = 'hours'
    if frequencyunit not in ['minutes', 'hours']:
        print('log frequency unit must be minutes or hours')
        exit()

    policy['backupPolicy']['log'] = {
        "schedule": makeSchedule(),
        "retention": makeRetention()
    }

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
    if 'remoteTargetPolicy' not in policy:
        policy['remoteTargetPolicy'] = {}
    if 'replicationTargets' not in policy['remoteTargetPolicy']:
        policy['remoteTargetPolicy']['replicationTargets'] = []
    existingReplica = [r for r in policy['remoteTargetPolicy']['replicationTargets'] if r['targetType'] == 'RemoteCluster' and r['remoteTargetConfig']['clusterName'].lower() == targetname.lower() and r['schedule']['unit'].lower() == frequencyunit.lower() and ('frequency' not in r['schedule'] or r['schedule']['frequency'] == frequency)]
    if existingReplica is None or len(existingReplica) == 0:
        newReplica = {
            "schedule": {
                "unit": frequencyunit.title()
            },
            "retention": makeRetention(),
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
        existingReplica[0]['retention'] = makeRetention()

# delete replica
if action == 'deletereplica':
    if targetname is None:
        print('--targetname required')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
    if 'remoteTargetPolicy' in policy and 'replicationTargets' in policy['remoteTargetPolicy']:
        newReplicationTargets = []
        changedReplicationTargets = False
        for replicationTarget in policy['remoteTargetPolicy']['replicationTargets']:
            includeThisReplica = True
            if replicationTarget['targetType'] == 'RemoteCluster' and replicationTarget['remoteTargetConfig']['clusterName'].lower() == targetname.lower():
                if allfortarget:
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
    if 'remoteTargetPolicy' not in policy:
        policy['remoteTargetPolicy'] = {}
    if 'archivalTargets' not in policy['remoteTargetPolicy']:
        policy['remoteTargetPolicy']['archivalTargets'] = []
    existingTarget = [t for t in policy['remoteTargetPolicy']['archivalTargets'] if t['targetId'] == thisVault['id']]
    if existingTarget is None or len(existingTarget) == 0:
        newTarget = {
            "schedule": {
                "unit": frequencyunit.title()
            },
            "retention": makeRetention(),
            "copyOnRunSuccess": False,
            "targetId": thisVault['id'],
            "targetName": thisVault['name'],
            "targetType": "Cloud"
        }
        if frequencyunit != 'runs':
            newTarget['schedule']['frequency'] = frequency
        policy['remoteTargetPolicy']['archivalTargets'].append(newTarget)
    else:
        existingTarget[0]['retention'] = makeRetention()

# delete archive
if action == 'deletearchive':
    if targetname is None:
        print('--targetname required')
        exit()
    if frequencyunit == 'minutes':
        print('--frequencyunit "minutes" is not valid for replication')
        exit()
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

# add quiet time
updatedQuietTimes = False
for quiettime in addquiettime:
    parts = quiettime.split(';')
    if len(parts) < 3:
        print('invalid quiet time specified')
        exit(1)
    days = parts[0]
    starttime = parts[1]
    endtime = parts[2]
    (starthour, startminute) = parseTime(starttime, 'quient time starttime')
    (endhour, endminute) = parseTime(endtime, 'quiet time endtime')
    if days == 'All':
        days = 'Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday'
    days = days.split(',')
    for day in days:
        day = day.strip().title()
        if day not in ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']:
            print('quiet time day invalid')
            exit(1)
        if 'blackoutWindow' not in policy or policy['blackoutWindow'] is None:
            policy['blackoutWindow'] = []
        policy['blackoutWindow'] = [bw for bw in policy['blackoutWindow'] if bw is not None and not (
            bw['day'] == day and bw['startTime']['hour'] == starthour and bw['startTime']['minute'] == startminute and bw['endTime']['hour'] == endhour and bw['endTime']['minute'] == endminute
        )]
        policy['blackoutWindow'].append({
            "day": day,
            "startTime": {
                "hour": starthour,
                "minute": startminute
            },
            "endTime": {
                "hour": endhour,
                "minute": endminute
            }
        })
        updatedQuietTimes = True

# remove quiet times
for quiettime in removequiettime:
    parts = quiettime.split(';')
    if len(parts) < 3:
        print('invalid quiet time specified')
        exit(1)
    days = parts[0]
    starttime = parts[1]
    endtime = parts[2]
    (starthour, startminute) = parseTime(starttime,'quiet time starttime')
    (endhour, endminute) = parseTime(endtime, 'quiet time endtime')
    if days == 'All':
        days = 'Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday'
    days = days.split(',')
    for day in days:
        day = day.strip().title()
        if day not in ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']:
            print('quiet time day invalid')
            exit(1)
        if 'blackoutWindow' not in policy:
            policy['blackoutWindow'] = []
        policy['blackoutWindow'] = [bw for bw in policy['blackoutWindow'] if bw is not None and not (
            bw['day'] == day and bw['startTime']['hour'] == starthour and bw['startTime']['minute'] == startminute and bw['endTime']['hour'] == endhour and bw['endTime']['minute'] == endminute
        )]
        updatedQuietTimes = True

if updatePolicy is True:
    result = api('put', 'data-protect/policies/%s' % policy['id'], policy, v=2)
    if 'error' in result:
        exit(1)

# list policies
for policy in policies:
    print('\n%s' % policy['name'])
    print(('-' * len(policy['name']) + '\n'))
    if 'retryOptions' in policy:
        print('Retry: %s times after %s minutes\n' % (policy['retryOptions']['retries'], policy['retryOptions']['retryIntervalMins']))
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
                if 'weekOfMonth' in backupSchedule[unitPath]:
                    print('  Incremental backup:  Monthly on the %s %s  (keep for %s %s%s)' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], baseRetention['duration'], baseRetention['unit'], dataLock))
                else:
                    print('  Incremental backup:  Monthly on day %s  (keep for %s %s%s)' % (backupSchedule[unitPath]['dayOfMonth'], baseRetention['duration'], baseRetention['unit'], dataLock))
    # full backup
    if 'fullBackups' in policy['backupPolicy']['regular'] and policy['backupPolicy']['regular']['fullBackups'] is not None and len(policy['backupPolicy']['regular']['fullBackups']) > 0:
        for fullBackup in policy['backupPolicy']['regular']['fullBackups']:
            backupSchedule = fullBackup['schedule']
            backupRetention = fullBackup['retention']
            unit = backupSchedule['unit']
            
            if 'dataLockConfig' in backupRetention and backupRetention['dataLockConfig'] is not None:
                fullDataLock = ', datalock for %s %s' % (backupRetention['dataLockConfig']['duration'], backupRetention['dataLockConfig']['unit'])
            else:
                fullDataLock = dataLock
            unitPath = '%sSchedule' % unit.lower()[:-1]
            if unit in frequentSchedules:
                frequency = backupSchedule[unitPath]['frequency']
                print('         Full backup:  Every %s %s  (keep for %s %s%s)' % (frequency, unit, backupRetention['duration'], backupRetention['unit'], fullDataLock))
            else:
                if unit == 'Weeks':
                    print('         Full backup:  Weekly on %s  (keep for %s %s%s)' % ((', '.join(backupSchedule[unitPath]['dayOfWeek'])), backupRetention['duration'], backupRetention['unit'], fullDataLock))
                elif unit == 'Months':
                    if 'weekOfMonth' in backupSchedule[unitPath]:
                        print('         Full backup:  Monthly on the %s %s  (keep for %s %s%s)' % (backupSchedule[unitPath]['weekOfMonth'], backupSchedule[unitPath]['dayOfWeek'][0], backupRetention['duration'], backupRetention['unit'], fullDataLock))
                    elif 'dayOfMonth' in backupSchedule[unitPath]:
                        print('         Full backup:  Monthly on day %s  (keep for %s %s%s)' % (backupSchedule[unitPath]['dayOfMonth'], backupRetention['duration'], backupRetention['unit'], fullDataLock))
                elif unit == 'Years':
                    print('         Full backup:  Yearly on the %s day  (keep for %s %s%s)' % (backupSchedule[unitPath]['dayOfYear'], backupRetention['duration'], backupRetention['unit'], fullDataLock))
                elif unit == 'ProtectOnce':
                    print('         Full backup:  Once (keep for %s %s%s)' % (backupRetention['duration'], backupRetention['unit'], fullDataLock))
                else:
                    display(fullBackup)
    # quiet times
    if 'blackoutWindow' in policy and policy['blackoutWindow'] is not None and len(policy['blackoutWindow']) > 0:
        print('         Quiet times:')
        for bw in policy['blackoutWindow']:
            print('                       %-9s %02d:%02d - %02d:%02d' % (bw['day'], bw['startTime']['hour'], bw['startTime']['minute'], bw['endTime']['hour'], bw['endTime']['minute']))
    # extended retention
    if 'extendedRetention' in policy and policy['extendedRetention'] is not None and len(policy['extendedRetention']) > 0:
        print('  Extended retention:')
        for extendedRetention in policy['extendedRetention']:
            dataLock = ''
            if 'dataLockConfig' in extendedRetention['retention']:
                dataLock = ', datalock for %s %s' % (extendedRetention['retention']['dataLockConfig']['duration'], extendedRetention['retention']['dataLockConfig']['unit'])
            if 'dataLock' in policy:
                dataLock = ', datalock for %s %s' % (extendedRetention['retention']['duration'], extendedRetention['retention']['unit'])
            print('                       Every %s %s  (keep for %s %s%s)' % (extendedRetention['schedule']['frequency'], extendedRetention['schedule']['unit'], extendedRetention['retention']['duration'], extendedRetention['retention']['unit'], dataLock))
    # log backup
    if 'log' in policy['backupPolicy']:
        logRetention = policy['backupPolicy']['log']['retention']
        backupSchedule = policy['backupPolicy']['log']['schedule']
        unit = backupSchedule['unit']
        unitPath = '%sSchedule' % unit.lower()[:-1]
        frequency = backupSchedule[unitPath]['frequency']
        dataLock = ''
        if 'dataLockConfig' in logRetention:
            dataLock = ', datalock for %s %s' % (logRetention['dataLockConfig']['duration'], logRetention['dataLockConfig']['unit'])
        if 'dataLock' in policy:
            dataLock = ', datalock for %s %s' % (logRetention['duration'], logRetention['unit'])
        print('          Log backup:  Every %s %s  (keep for %s %s%s)' % (frequency, unit, logRetention['duration'], logRetention['unit'], dataLock))
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
                dataLock = ''
                if 'dataLockConfig' in replicationTarget['retention']:
                    dataLock = ', datalock for %s %s' % (replicationTarget['retention']['dataLockConfig']['duration'], replicationTarget['retention']['dataLockConfig']['unit'])
                if 'dataLock' in policy:
                    dataLock = ', datalock for %s %s' % (replicationTarget['retention']['duration'], replicationTarget['retention']['unit'])
                print('                       %s:  Every %s %s  (keep for %s %s%s)' % (targetName, frequency, frequencyunit, replicationTarget['retention']['duration'], replicationTarget['retention']['unit'], dataLock))
        # archive targets
        if 'archivalTargets' in policy['remoteTargetPolicy'] and policy['remoteTargetPolicy']['archivalTargets'] is not None and len(policy['remoteTargetPolicy']['archivalTargets']) > 0:
            print('          Archive To:')
            for archivalTarget in policy['remoteTargetPolicy']['archivalTargets']:
                frequencyunit = archivalTarget['schedule']['unit']
                if frequencyunit == 'Runs':
                    frequencyunit = 'Run'
                    frequency = 1
                else:
                    frequency = archivalTarget['schedule']['frequency']
                dataLock = ''
                if 'dataLockConfig' in archivalTarget['retention']:
                    dataLock = ', datalock for %s %s' % (archivalTarget['retention']['dataLockConfig']['duration'], archivalTarget['retention']['dataLockConfig']['unit'])
                if 'dataLock' in policy:
                    dataLock = ', datalock for %s %s' % (archivalTarget['retention']['duration'], archivalTarget['retention']['unit'])
                print('                       %s:  Every %s %s  (keep for %s %s%s)' % (archivalTarget['targetName'], frequency, frequencyunit, archivalTarget['retention']['duration'], archivalTarget['retention']['unit'], dataLock))
    print('')
