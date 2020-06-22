#!/usr/bin/env python
"""Clone a Cohesity View Using python"""

### usage: ./cloneView.py -s mycluster -u admin -d domain -v myview -n newview -w

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-j', '--jobname', type=str)  # Job name
parser.add_argument('-v', '--view', type=str, required=True)  # name of source view to clone
parser.add_argument('-n', '--newname', type=str, required=True)  # name of target view to create
parser.add_argument('-f', '--filedate', type=str, default=None)  # date time to recover view to
parser.add_argument('-b', '--before', action='store_true')  # use snapshot before file date (default is after)
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
viewName = args.view
newName = args.newname
jobName = args.jobname
filedate = args.filedate
before = args.before
wait = args.wait

### authenticate
apiauth(vip, username, domain)

### search for view to clone
searchResults = api('get', '/searchvms?entityTypes=kView&vmName=%s' % viewName)
if len(searchResults) == 0:
    print("View %s not found" % viewName)
    exit()

### narrow search results to the correct view
viewResults = [viewResult for viewResult in searchResults['vms'] if viewResult['vmDocument']['objectName'].lower() == viewName.lower()]
if len(viewResults) == 0:
    print("View %s not found" % viewName)
    exit()

if jobName is not None:
    viewResults = [v for v in viewResults if v['vmDocument']['jobName'].lower() == jobName.lower()]
if len(viewResults) == 0:
    print("View %s not found" % viewName)
    exit()

doc = viewResults[0]['vmDocument']

view = api('get', 'views/%s?includeInactive=True' % doc['objectName'])

if filedate is not None:
    if ':' not in filedate:
        filedate = '%s 00:00:00' % filedate
    filedateusecs = dateToUsecs(filedate)
    if before:
        versions = [v for v in doc['versions'] if filedateusecs > v['snapshotTimestampUsecs']]
        if versions:
            version = versions[0]
        else:
            print('No backups from the specified date')
            exit(1)
    else:
        versions = [v for v in doc['versions'] if filedateusecs <= v['snapshotTimestampUsecs']]
        if versions:
            version = versions[-1]
        else:
            print('No backups from the specified date')
            exit(1)
else:
    version = doc['versions'][0]

taskName = "Clone-View_%s_as_%s" % (viewName, newName)

cloneTask = {
    "name": taskName,
    "objects": [
        {
            "jobUid": doc['objectId']['jobUid'],
            "jobId": doc['objectId']['jobId'],
            "jobInstanceId": version['instanceId']['jobInstanceId'],
            "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
            "entity": doc['objectId']['entity']
        }
    ],
    "viewName": newName,
    "action": 5,
    "viewParams": {
        "sourceViewName": view['name'],
        "cloneViewName": newName,
        "viewBoxId": view['viewBoxId'],
        "viewId": doc['objectId']['entity']['id']
    }
}

### execute the clone task
response = api('post', '/clone', cloneTask)

if 'errorCode' in response:
    exit(1)

print("Cloning View %s as %s..." % (viewName, newName))
print("Backup date: %s" % usecsToDate(version['instanceId']['jobStartTimeUsecs']))

# wait for completion and report status
taskId = response['restoreTask']['performRestoreTaskState']['base']['taskId']
status = api('get', '/restoretasks/%s' % taskId)

if wait is True:
    finishedStates = ['kCanceled', 'kSuccess', 'kFailure']
    while(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] not in finishedStates):
        sleep(1)
        status = api('get', '/restoretasks/%s' % taskId)
    if(status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess'):
        print('Cloned View Successfully')
        exit(0)
    else:
        print('Clone View ended with state: %s' % status[0]['restoreTask']['performRestoreTaskState']['base']['publicStatus'])
        exit(1)
