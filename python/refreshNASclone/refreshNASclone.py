#!/usr/bin/env python
"""Recover a NAS Volume as a Cohesity View Using python"""

### usage: ./refreshNASclone.py -s mycluster -u myuser -v '\\mynas.mydomain.net\Utils' -n test [ -smb ]

### import pyhesity wrapper module
from pyhesity import *
from urllib import quote_plus
from datetime import datetime
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-v', '--volume', type=str, required=True)
parser.add_argument('-n', '--newname', type=str, required=True)
parser.add_argument('-smb', '--smbsettings', action='store_true')

args = parser.parse_args()

server = args.server
username = args.username
domain = args.domain
volume = args.volume
newname = args.newname
smb = args.smbsettings

finishedStates = ['kCanceled', 'kSuccess', 'kFailure']

### authenticate
apiauth(server, username, domain, quiet=True)

quoted_volume = quote_plus(volume)
items = api('get', '/searchvms?entityTypes=kNetapp&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kFlashBlade&entityTypes=kPure&vmName=%s' % quoted_volume)

f = open('log-refreshNASclone.txt', 'w')
f.write('started at %s\n' % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

if len(items) == 0:
    f.write('volume %s not found\n' % volume)
    f.close()
    exit()

item = [item for item in items['vms'] if item['vmDocument']['objectName'].lower() == volume.lower()]

if len(item) == 0:
    f.write('volume %s not found\n' % volume)
    f.close()
    exit()

doc = item[0]['vmDocument']
version = item[0]['vmDocument']['versions'][0]

# delete existing view if it exists
view = [view for view in api('get', 'views')['views'] if view['name'].lower() == newname.lower()]
if(view):
    if((view[0]['createTimeMsecs']) * 1000 <= version['instanceId']['jobStartTimeUsecs']):
        f.write('deleting view %s\n' % view[0]['name'])
        result = api('delete', 'views/%s' % view[0]['name'])
        sleep(5)
    else:
        f.write('no new version of %s\n' % volume)
        f.close()
        exit()

# recover nas volume as view
now = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
rundate = usecsToDate(version['instanceId']['jobStartTimeUsecs']).replace(' ', '-').replace(':', '-')
recoverTask = {
    "name": "%s-%s" % (newname, now),
    "objects": [
        {
            "jobId": doc['objectId']['jobId'],
            "jobUid": {
                "clusterId": doc['objectId']['jobUid']['clusterId'],
                "clusterIncarnationId": doc['objectId']['jobUid']['clusterIncarnationId'],
                "id": doc['objectId']['jobUid']['objectId']
            },
            "jobRunId": version['instanceId']['jobInstanceId'],
            "startedTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
            "protectionSourceId": doc['objectId']['entity']['id']
        }
    ],
    "type": "kMountFileVolume",
    "viewName": newname,
    "restoreViewParameters": {
        "qos": {
            "principalName": "TestAndDev High"
        }
    }
}
f.write('recovering %s from %s to %s\n' % (volume, usecsToDate(version['instanceId']['jobStartTimeUsecs']), newname))
result = api('post', 'restore/recover', recoverTask)
recoverTaskId = result['id']

# wait for task to complete
recoverStatus = 'kUnkown'
while(recoverStatus not in finishedStates):
    sleep(5)
    recoverStatus = api('get', '/restoretasks/%s' % recoverTaskId)[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus']

if smb:
    # update view parameters
    view = api('get', 'views/%s' % newname)
    view['protocolAccess'] = 'kSMBOnly'
    view['enableSmbViewDiscovery'] = True
    view['enableSmbAccessBasedEnumeration'] = True
    updateview = api('put', 'views/%s' % newname, view)

f.close()
