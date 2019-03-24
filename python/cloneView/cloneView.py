#!/usr/bin/env python
"""Clone a Cohesity View Using python"""

### usage: ./cloneView.py -s mycluster -u admin -d domain -v myview -n newview

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-v', '--view', type=str, required=True)
parser.add_argument('-n', '--name', type=str, required=True)

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
viewName = args.view
newName = args.name

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
        "viewId": viewResult['vmDocument']['objectId']['entity']['id'],
        "qos": view['qos'],
        "description": view['description'],
        "allowMountOnWindows": view['allowMountOnWindows'],
        "storagePolicyOverride": view['storagePolicyOverride']
    }
}

### execute the clone task
response = api('post', '/clone', cloneTask)
print("Cloning View %s as %s..." % (viewName, newName))
