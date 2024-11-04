#!/usr/bin/env python
"""clone and protect views for disaster recovery"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
import os
import json

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--viewName', type=str, action='append', default=None)
parser.add_argument('-l', '--viewList', type=str, default=None)
parser.add_argument('-p', '--policyName', type=str, default=None)
parser.add_argument('-a', '--allViews', action='store_true')
parser.add_argument('-m', '--metadataPath', type=str, required=True)
parser.add_argument('-s', '--snapshotDate', type=str, default=None)
parser.add_argument('-k', '--keepRemoteViewName', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
viewNames = args.viewName
viewList = args.viewList
policyName = args.policyName
allViews = args.allViews
metadataPath = args.metadataPath
snapshotDate = args.snapshotDate
keepRemoteViewName = args.keepRemoteViewName

# gather view names from command line and file
if viewNames is None:
    viewNames = []
if viewList is not None:
    f = open(viewList, 'r')
    viewNames += [s.strip().lower() for s in f.readlines() if s.strip() != '']
    f.close()
if allViews is False and len(viewNames) == 0:
    print("No views selected")
    exit(1)

# gather metadata from source cluster
viewMetadata = []
if os.path.isdir(metadataPath) is False:
    print('metadataPath %s not found' % metadataPath)
    exit(1)

for fileName in os.listdir(metadataPath):
    filePath = os.path.join(metadataPath, fileName)
    f = open(filePath, 'r')
    view = json.load(f)
    viewMetadata.append(view)
    f.close()

if allViews:
    viewNames = [v['name'] for v in viewMetadata]
viewNames = list(set(viewNames))

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# get cluster info
cluster = api('get', 'cluster')

# get view protection jobs
jobs = api('get', 'protectionJobs?environments=kView')

# get policy info
if policyName is not None:
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyName.lower()]
    if policy is None or len(policy) == 0:
        print('Policy %s not found' % policyName)
        exit(1)
    else:
        policy = policy[0]

# get existing views
views = api('get', 'views?includeInactive=True')
activeViews = api('get', 'views')

# setup output files
clonedViewList = './clonedViews.txt'
migratedShares = './migratedShares.txt'
if os.path.exists(clonedViewList):
    os.remove(clonedViewList)
if os.path.exists(migratedShares):
    os.remove(migratedShares)

viewJobs = {}
migratedViews = []
remoteViewNames = {}

# process selected views
for viewName in viewNames:
    processView = False
    existingView = [v for v in activeViews['views'] if v['name'].lower() == viewName.lower()]
    if existingView is not None and len(existingView) > 0:
        print('View %s already exists' % viewName)
    else:
        # find replicated view backups
        searchResults = api('get', '/searchvms?entityTypes=kView&vmName=%s' % viewName)
        if searchResults is not None and 'vms' in searchResults:
            viewResults = [v for v in searchResults['vms'] if v['vmDocument']['objectName'].lower() == viewName.lower()]
            if viewResults is None or len(viewResults) == 0:
                print('View %s is not replicated to this cluster' % viewName)
            else:
                # use latest incarnation of the view
                viewResult = sorted(viewResults, key=lambda r: r['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]
                metadata = [m for m in viewMetadata if m['name'].lower() == viewName.lower()]
                # ensure view name is proper case
                if metadata is None or len(metadata) == 0:
                    viewName = viewResult['vmDocument']['objectName']
                else:
                    viewName = metadata[0]['name']
                processView = True
                # determine the remote view name
                job = [j for j in jobs if j['name'].lower() == viewResult['vmDocument']['jobName'].lower()]
                if job is None or len(job) == 0:
                    print('View %s is not replicated to this cluster' % viewName)
                else:
                    job = job[0]
                    remoteViews = [v for v in views['views'] if 'viewProtection' in v and job['name'] in [j['jobName'] for j in v['viewProtection']['protectionJobs']]]
                    remoteView = sorted(remoteViews, key=lambda v: v['viewId'], reverse=True)[0]
                    remoteViewNames[viewName] = remoteView['name']
                    # clone from remote view
                    if 'remoteViewName' in job and snapshotDate is None:
                        cloneTask = {
                            "name": "Clone-View_%s" % viewName,
                            "objects": [
                                {
                                    "entity": {
                                        "type": 4,
                                        "viewEntity": {
                                            "name": remoteView['name'],
                                            "uid": {
                                                "clusterId": cluster['id'],
                                                "clusterIncarnationId": cluster['incarnationId'],
                                                "objectId": remoteView['viewId']
                                            },
                                            "type": 1
                                        }
                                    }
                                }
                            ],
                            "viewName": viewName,
                            "action": 5,
                            "viewParams": {
                                "sourceViewName": remoteView['name'],
                                "cloneViewName": viewName,
                                "viewBoxId": remoteView['viewBoxId'],
                                "viewId": remoteView['viewId']
                            }
                        }
                        version = viewResult['vmDocument']['versions'][0]
                    else:
                        # clone from a previous snapshot
                        version = None
                        if snapshotDate is not None:
                            snapshotUsecs = dateToUsecs(snapshotDate)
                            versions = [v for v in viewResult['vmDocument']['versions'] if v['instanceId']['jobStartTimeUsecs'] <= (snapshotUsecs + 60000000)]
                            if versions is not None and len(versions) > 0:
                                version = versions[0]
                            else:
                                processView = False
                                print('No backups for %s available from %s' % (viewName, snapshotDate))
                        else:
                            version = viewResult['vmDocument']['versions'][0]
                        if version is not None:
                            cloneTask = {
                                "name": "Clone-View_%s" % viewName,
                                "objects": [
                                    {
                                        "jobUid": viewResult['vmDocument']['objectId']['jobUid'],
                                        "jobId": viewResult['vmDocument']['objectId']['jobId'],
                                        "jobInstanceId": version['instanceId']['jobInstanceId'],
                                        "startTimeUsecs": version['instanceId']['jobStartTimeUsecs'],
                                        "entity": viewResult['vmDocument']['objectId']['entity']
                                    }
                                ],
                                "viewName": viewName,
                                "action": 5,
                                "viewParams": {
                                    "sourceViewName": remoteView['name'],
                                    "cloneViewName": viewName,
                                    "viewBoxId": remoteView['viewBoxId'],
                                    "viewId": viewResult['vmDocument']['objectId']['entity']['id']
                                }
                            }

                    # perform the clone
                    if processView is True:
                        cloneOp = api('post', '/clone', cloneTask)

                    if cloneOp is not None:
                        viewJobs[viewName] = job
                        migratedViews.append(viewName)

                        # update files
                        print('Cloned %s from %s' % (viewName, usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
                        f = open(clonedViewList, 'a')
                        f.write('%s\n' % viewName)
                        f.close()
                        f = open(migratedShares, 'a')
                        f.write('%s\n' % viewName)
                        f.close()

                    # delete existing remote view(s)
                    if remoteViews is not None and len(remoteViews) > 0:
                        for oldView in remoteViews:
                            if oldView['name'].lower() != viewName.lower():
                                result = api('delete', 'views/%s' % oldView['name'])
        else:
            print('No backups available for %s' % viewName)

sleep(3)

# get existing views
views = api('get', 'views')

for viewName in migratedViews:
    newView = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if newView is not None and len(newView) > 0:
        newView = newView[0]
        # update unreplicated view settings from stored metadata
        metadata = [m for m in viewMetadata if m['name'].lower() == viewName.lower()]
        if metadata is None or len(metadata) == 0:
            print('No metadata for %s' % viewName)
            metadata = None
        else:
            metadata = metadata[0]
            # create child shares
            if 'aliases' in metadata:
                print('Creating %s child shares...' % viewName)
                for alias in metadata['aliases']:
                    print('\t%s' % alias['aliasName'])
                    viewPath = alias['viewPath']
                    if viewPath.endswith('/'):
                        viewPath = viewPath[:-1]
                    result = api('post', 'viewAliases', {'viewName': newView['name'], 'viewPath': viewPath, 'aliasName': alias['aliasName'], 'sharePermissions': alias['sharePermissions']})
                    f = open(migratedShares, 'a')
                    f.write('%s\n' % alias['aliasName'])
                    f.close()
            # update other settings
            if 'subnetWhitelist' in metadata:
                newView['subnetWhitelist'] = metadata['subnetWhitelist']
            newView['enableSmbViewDiscovery'] = metadata['enableSmbViewDiscovery']
            newView['qos'] = {"principalName": metadata['qos']['principalName']}
            result = api('put', 'views', newView)

        # protect new view
        if policyName is not None:
            job = viewJobs[viewName]
            job['isActive'] = True
            job['viewName'] = newView['name']
            job['name'] = '%s %s Backup' % (cluster['name'], newView['name'])
            job['policyId'] = policy['id']
            job['sourceIds'] = [newView['viewId']]
            job['viewBoxId'] = newView['viewBoxId']
            del job['parentSourceId']
            del job['id']
            del job['missingEntities']
            del job['uid']
            print('Protecting %s with %s...' % (viewName, policyName))
            result = api('post', 'protectionJobs', job)
            # rename new view
            if keepRemoteViewName is True:
                print('renaming %s to %s...' % (viewName, remoteViewNames[viewName]))
                sleep(2)
                result = api('post', 'views/rename/%s' % viewName, {"newViewName": remoteViewNames[viewName]})
