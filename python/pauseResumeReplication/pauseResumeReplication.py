#!/usr/bin/env python
"""Pause and resume replication"""

### import pyhesity wrapper module
from pyhesity import *

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
parser.add_argument('-p', '--pause', action='store_true')
parser.add_argument('-r', '--resume', action='store_true')
parser.add_argument('-cad', '--cloudarchivedirect', action='store_true')
parser.add_argument('-ip', '--incrementalsnapshotprefix', type=str, default=None)
parser.add_argument('-fp', '--fullsnapshotprefix', type=str, default=None)
parser.add_argument('-enc', '--encryptionenabled', action='store_true')

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
pause = args.pause
resume = args.resume


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
        if pause is True:
            print('pausing replication to %s' % remotecluster['name'])
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
        elif resume is True:
            print('resuming replication to %s' % remotecluster['name'])
            if 'bandwidthLimit' in remotecluster:
                del remotecluster['bandwidthLimit']
        result = api('put', 'remoteClusters/%s' % remotecluster['clusterId'], remotecluster)
