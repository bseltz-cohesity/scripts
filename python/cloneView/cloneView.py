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
parser.add_argument('-v', '--view', type=str, required=True)  # name of source view to clone
parser.add_argument('-n', '--newname', type=str, required=True)  # name of target view to create
parser.add_argument('-w', '--wait', action='store_true')  # wait for completion

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
viewName = args.view
newName = args.newname
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

viewResult = viewResults[0]

view = api('get', 'views/%s?includeInactive=True' % viewResult['vmDocument']['objectName'])

taskName = "Clone-View_%s_as_%s" % (viewName, newName)

cloneTask = {
    "name": taskName,
    "objects": [
        {
            "jobUid": viewResult['vmDocument']['objectId']['jobUid'],
            "jobId": viewResult['vmDocument']['objectId']['jobId'],
            "jobInstanceId": viewResult['vmDocument']['versions'][0]['instanceId']['jobInstanceId'],
            "startTimeUsecs": viewResult['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs'],
            "entity": viewResult['vmDocument']['objectId']['entity']
        }
    ],
    "viewName": newName,
    "action": 5,
    "viewParams": {
        "sourceViewName": view['name'],
        "cloneViewName": newName,
        "viewBoxId": view['viewBoxId'],
        "viewId": viewResult['vmDocument']['objectId']['entity']['id']
    }
}

### execute the clone task
response = api('post', '/clone', cloneTask)

if 'errorCode' in response:
    exit(1)

print("Cloning View %s as %s..." % (viewName, newName))
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
