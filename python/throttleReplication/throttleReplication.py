#!/usr/bin/env python
"""Pause and resume replication"""

### import pyhesity wrapper module
from pyhesity import *
import getpass

### command line arguments
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
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--remoteclustername', action='append', type=str)
parser.add_argument('-l', '--remoteclusterlist', type=str)
parser.add_argument('-ru', '--remoteusername', type=str, default=None)
parser.add_argument('-rp', '--remotepassword', type=str, default=None)
parser.add_argument('-pp', '--promotforremotepassword', action='store_true')
parser.add_argument('-block', '--block', action='store_true')
parser.add_argument('-limit', '--limit', action='store_true')
parser.add_argument('-clear', '--clear', action='store_true')
parser.add_argument('-e', '--everyday', action='store_true')
parser.add_argument('-w', '--weekdays', action='store_true')
parser.add_argument('-sun', '--sunday', action='store_true')
parser.add_argument('-mon', '--monday', action='store_true')
parser.add_argument('-tue', '--tuesday', action='store_true')
parser.add_argument('-wed', '--wednesday', action='store_true')
parser.add_argument('-thu', '--thursday', action='store_true')
parser.add_argument('-fri', '--friday', action='store_true')
parser.add_argument('-sat', '--saturday', action='store_true')
parser.add_argument('-st', '--starttime', type=str, default='09:00')
parser.add_argument('-et', '--endtime', type=str, default='17:00')
parser.add_argument('-b', '--bandwidth', type=int, default=0)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')

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
emailmfacode = args.emailmfacode
remoteclustername = args.remoteclustername
remoteclusterlist = args.remoteclusterlist
remoteusername = args.remoteusername
remotepassword = args.remotepassword
promotforremotepassword = args.promotforremotepassword
block = args.block
limit = args.limit
clear = args.clear
everyday = args.everyday
weekdays = args.weekdays
sunday = args.sunday
monday = args.monday
tuesday = args.tuesday
wednesday = args.wednesday
thursday = args.thursday
friday = args.friday
saturday = args.saturday
starttime = args.starttime
endtime = args.endtime
bandwidth = args.bandwidth
timezone = args.timezone

# parse starttime
try:
    (starthour, startminute) = starttime.split(':')
    starthour = int(starthour)
    startminute = int(startminute)
    if starthour < 0 or starthour > 23 or startminute < 0 or startminute > 59:
        print('starttime is invalid!')
        exit(1)
except Exception:
    print('starttime is invalid!')
    exit(1)

# parse endtime
try:
    (endhour, endminute) = endtime.split(':')
    endhour = int(endhour)
    endminute = int(endminute)
    if endhour < 0 or endhour > 23 or endminute < 0 or endminute > 59:
        print('endtime is invalid!')
        exit(1)
except Exception:
    print('endtime is invalid!')
    exit(1)


# gather list
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


# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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

remoteclusternames = gatherList(remoteclustername, remoteclusterlist, name='remote clusters', required=False)

remoteclusters = api('get', 'remoteClusters')

for remotecluster in remoteclusters:
    if len(remoteclusternames) == 0 or remotecluster['name'].lower() in [n.lower() for n in remoteclusternames]:
        if block is True:
            print('blocking replication to %s' % remotecluster['name'])
            remotecluster['bandwidthLimit'] = {
                "rateLimitBytesPerSec": 1,
                "bandwidthLimitOverrides": [
                    {
                        "bytesPerSecond": 0,
                        "timePeriods": {
                            "days": [
                                "kFriday",
                                "kMonday",
                                "kSaturday",
                                "kSunday",
                                "kThursday",
                                "kTuesday",
                                "kWednesday"
                            ],
                            "startTime": {
                                "hour": 0,
                                "minute": 0
                            },
                            "endTime": {
                                "hour": 23,
                                "minute": 59
                            }
                        }
                    }
                ],
                "timezone": "America/New_York"
            }
        elif clear is True:
            print('clearing all throttles to %s' % remotecluster['name'])
            if 'bandwidthLimit' in remotecluster:
                del remotecluster['bandwidthLimit']
        else:
            days = []
            if everyday:
                days = ["kSunday", "kMonday", "kTuesday", "kWednesday", "kThursday", "kFriday", "kSaturday"]
            elif weekdays:
                days = ["kMonday", "kTuesday", "kWednesday", "kThursday", "kFriday"]
            else:
                if sunday:
                    days.append('kSunday')
                if monday:
                    days.append('kMonday')
                if tuesday:
                    days.append('kTuesday')
                if wednesday:
                    days.append('kWednesday')
                if thursday:
                    days.append('kThursday')
                if friday:
                    days.append('kFriday')
                if saturday:
                    days.append('kSaturday')
            if len(days) > 0:
                bytesPerSecond = int(bandwidth * 1024 * 1024 / 8)
                if 'bandwidthLimit' not in remotecluster:
                    remotecluster['bandwidthLimit'] = {}
                remotecluster['bandwidthLimit']['timezone'] = timezone
                remotecluster['bandwidthLimit']['bandwidthLimitOverrides'] = [
                    {
                        "bytesPerSecond": bytesPerSecond,
                        "timePeriods": {
                            "days": days,
                            "startTime": {
                                "hour": starthour,
                                "minute": startminute
                            },
                            "endTime": {
                                "hour": endhour,
                                "minute": endminute
                            }
                        }
                    }
                ]
                print('applying quiet period throttle to %s' % remotecluster['name'])
            if limit:
                if 'bandwidthLimit' not in remotecluster:
                    remotecluster['bandwidthLimit'] = {}
                if bandwidth == 0:
                    bytesPerSecond = 1
                else:
                    bytesPerSecond = int(bandwidth * 1024 * 1024 / 8)
                remotecluster['bandwidthLimit']['rateLimitBytesPerSec'] = bytesPerSecond
                print('applying bandwidth limit to %s' % remotecluster['name'])

        if remoteusername is None:
            remoteusername = remotecluster['userName']
        else:
            remotecluster['userName'] = remoteusername

        if promotforremotepassword is True:
            remotepassword = getpass.getpass("  Enter password for user %s at %s: " % (remoteusername, remotecluster['name']))

        if remotepassword is not None:
            remotecluster['password'] = remotepassword

        result = api('put', 'remoteClusters/%s' % remotecluster['clusterId'], remotecluster)
