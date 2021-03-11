#!/usr/bin/env python
"""Show Object Protection Status"""

### usage: ./objectProtectionStatus.py -v mycluster \
#                                      -u admin \
#                                      -d mydomain.net \
#                                      -o myserver.mydomain.net \
#                                      -n mydatabase

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-o', '--object', type=str, required=True)
parser.add_argument('-n', '--dbname', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
objectname = args.object
dbname = args.dbname

### authenticate
apiauth(vip, username, domain)

sources = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false&allUnderHierarchy=true')

dbenvironments = ['kSQL', 'kOracle']

foundObject = False
jobs = []
jobnames = []
objectId = None

print('searching for %s' % objectname)

for rootNode in sources['rootNodes']:
    parentId = rootNode['rootNode']['id']
    parentName = rootNode['rootNode']['name']
    if parentName.lower() == objectname.lower():
        foundObject = True
        objectId = parentId
    # gather environments (e.g. physical and SQL)
    environments = []
    environments.append(rootNode['rootNode']['environment'])
    if 'environments' in rootNode['registrationInfo']:
        for environment in rootNode['registrationInfo']['environments']:
            environments.append(environment)
    # find protected objects for each environment
    for environment in environments:
        protectedSources = api('get', 'protectionSources/protectedObjects?id=%s&environment=%s' % (parentId, environment))
        for protectedSource in protectedSources:
            childName = protectedSource['protectionSource']['name']
            childId = protectedSource['protectionSource']['id']
            if childName.lower() == objectname.lower():
                foundObject = True
                objectId = childId
            for job in protectedSource['protectionJobs']:
                jobName = job['name']
                jobId = job['id']
                if foundObject is True:
                    if jobName not in jobnames:
                        jobs.append(job)
                        jobnames.append(jobName)
            if foundObject is True and protectedSource['protectionSource']['environment'] not in dbenvironments:
                break
    if foundObject is True:
        break


### get object ID
def getObjectId(objectname):

    d = {'_object_id': None}

    def get_nodes(node):
        if 'name' in node:
            if node['name'].lower() == objectname.lower():
                d['_object_id'] = node['id']
        if 'protectionSource' in node:
            if node['protectionSource']['name'].lower() == objectname.lower():
                d['_object_id'] = node['protectionSource']['id']
        if 'nodes' in node:
            for node in node['nodes']:
                if d['_object_id'] is None:
                    get_nodes(node)
                else:
                    break

    for source in sources:
        if d['_object_id'] is None:
            get_nodes(source)

    return d['_object_id']


# jobs = [job for job in api('get', 'protectionJobs') if 'isDeleted' not in job and ('isActive' not in job or job['isActive'] is not False)]
# sources = api('get', 'protectionSources')
sqlSources = api('get', 'protectionSources?environments=kSQL')
oracleSources = api('get', 'protectionSources?environments=kOracle')
jobReports = []

# objectId = getObjectId(objectname)
if objectId is None:
    print("None::Not Found")
    exit(1)
else:
    foundProtectedObject = False
    objectJobIDs = []
    for job in jobs:
        environment = job['environment']
        parentId = job['parentSourceId']

        sourceIds = job.get('sourceIds', [])

        if environment != 'kOracle' and environment != 'kSQL':
            protectedObjects = api('get', 'protectionSources/protectedObjects?environment=%s&id=%s' % (environment, parentId))
            protectedObjects = [o for o in protectedObjects if o['protectionSource']['id'] == objectId]
            for protectedObject in protectedObjects:
                for protectionJob in protectedObject['protectionJobs']:
                    objectJobIDs.append(protectionJob['id'])
        else:
            for sourceId in sourceIds:
                protectedObjects = api('get', 'protectionSources/protectedObjects?environment=%s&id=%s' % (environment, sourceId))
                protectedObjects = [o for o in protectedObjects if o['protectionSource']['parentId'] == objectId]
                for protectedObject in protectedObjects:
                    for protectionJob in protectedObject['protectionJobs']:
                        objectJobIDs.append(protectionJob['id'])

    if len(objectJobIDs) == 0:
        print("None::Not Protected")
        exit(1)
    else:
        for job in [j for j in jobs if j['id'] in objectJobIDs]:
            foundProtectedObject = True
            jobName = job['name']
            jobType = job['environment'][1:]
            jobReport = {'jobName': jobName, 'jobType': jobType, 'dbList': [], 'objectStatus': 'Protected', 'objectLastRun': 0}

            # get list of protected SQL DBs for this object
            if job['environment'] == 'kSQL' or job['environment'] == 'kOracle':
                dbList = []
                protectedDbIds = []
                if job['environment'] == 'kSQL':
                    for node in sqlSources[0]['nodes']:
                        for applicationNode in node['applicationNodes']:
                            for node in applicationNode['nodes']:
                                if node['protectionSource']['parentId'] == objectId:
                                    dbList.append(node)
                    protectedDbList = api('get', 'protectionSources/protectedObjects?environment=kSQL&id=%s' % objectId)
                else:
                    for node in oracleSources[0]['nodes']:
                        if node['protectionSource']['id'] == objectId:
                            for applicationNode in node['applicationNodes']:
                                dbList.append(applicationNode)
                    protectedDbList = api('get', 'protectionSources/protectedObjects?environment=kOracle&id=%s' % objectId)
                for protectedDb in protectedDbList:
                    protectedDbIds.append(protectedDb['protectionSource']['id'])

                for db in dbList:
                    if db['protectionSource']['id'] in protectedDbIds:
                        # db is protected by some job
                        protectedDbs = [p for p in protectedDbList if p['protectionSource']['id'] == db['protectionSource']['id']]
                        for protectedDb in protectedDbs:
                            dbJobNames = []
                            for dbJob in protectedDb['protectionJobs']:
                                dbJobNames.append(dbJob['name'].lower())
                            if jobName.lower() in dbJobNames:
                                # protected by this job
                                jobReport['dbList'].append({'name': db['protectionSource']['name'], 'shortname': db['protectionSource']['name'].split('/')[-1], 'status': 'Protected', 'lastrun': 'None'})
                            else:
                                # protected by another job
                                jobReport['dbList'].append({'name': db['protectionSource']['name'], 'shortname': db['protectionSource']['name'].split('/')[-1], 'status': 'Protected - Other Job', 'lastrun': 'None'})
                    else:
                        # db is not protected
                        jobReport['dbList'].append({'name': db['protectionSource']['name'], 'shortname': db['protectionSource']['name'].split('/')[-1], 'status': 'Not Protected', 'lastrun': 'None'})

            yesterday = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S")) - 86400000000

            # find latest recovery points
            search = api('get', '/searchvms?showAll=false&onlyLatestVersion=true&vmName=%s' % objectname)
            if 'vms' in search:
                searchResults = [vm for vm in search['vms'] if vm['vmDocument']['jobName'].lower() == jobName.lower()]
                for db in jobReport['dbList']:
                    searchResult = [s for s in searchResults if s['vmDocument']['objectName'].lower() == db['name'].lower()]
                    if len(searchResult) > 0:
                        db['status'] = 'Success'
                        db['lastrun'] = searchResult[0]['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs']
                        if db['lastrun'] > jobReport['objectLastRun']:
                            jobReport['objectLastRun'] = db['lastrun']
                            jobReport['objectStatus'] = 'Success'

            # get latest run
            runs = api('get', 'protectionRuns?jobId=%s&excludeTasks=true&numRuns=1' % job['id'])
            # runs = sorted(api('get', 'protectionRuns?jobId=%s&excludeTasks=true&startTimeUsecs=%s' % (job['id'], yesterday)), key=lambda run: run['backupRun']['stats']['startTimeUsecs'])
            foundRun = False
            for run in runs:
                runStart = run['backupRun']['stats']['startTimeUsecs']
                thisRun = api('get', '/backupjobruns?id=%s&exactMatchStartTimeUsecs=%s' % (job['id'], runStart))
                # still running?
                if 'activeAttempt' in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']:
                    for attempt in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['activeAttempt']:
                        if 'sources' in attempt:
                            for source in attempt['sources']:
                                if source['id'] == objectId:
                                    if jobReport['objectStatus'] != 'Success':
                                        jobReport['objectStatus'] = 'Running'
                                        jobReport['objectLastRun'] = runStart
                            if 'appEntityStateVec' in attempt:
                                for app in attempt['appEntityStateVec']:
                                    db = [db for db in jobReport['dbList'] if db['name'].lower() == app['appEntity']['displayName'].lower()]
                                    if len(db) > 0:
                                        if db['status'] != 'Success':
                                            db['lastrun'] = runStart
                                            db['status'] = 'Running'
                # completed run
                if 'latestFinishedTasks' in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']:
                    for task in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks']:
                        if task['base']['sources'][0]['source']['id'] == objectId:
                            jobReport['objectStatus'] = task['base']['publicStatus'][1:]
                            jobReport['objectLastRun'] = runStart
                        if 'appEntityStateVec' in task:
                            for app in task['appEntityStateVec']:
                                db = [d for d in jobReport['dbList'] if d['name'].lower() == app['appEntity']['displayName'].lower()]
                                if len(db) > 0:
                                    db[0]['lastrun'] = runStart
                                    if 'publicStatus' in app:
                                        db[0]['status'] = app['publicStatus'][1:]
                                    else:
                                        db[0]['status'] = 'warnings'

            jobReports.append(jobReport)

    foundObject = False
    dbReported = False
    for jobReport in jobReports:
        foundObject = True
        shortnames = [d['shortname'].lower() for d in jobReport['dbList']]
        names = [d['name'].lower() for d in jobReport['dbList']]
        if (dbname is None) or (dbname.lower() in shortnames) or (dbname.lower() in names):
            print('\n    Job Name: %s (%s)' % (jobReport['jobName'], jobReport['jobType']))
            print(' Object Name: %s (%s)' % (objectname, jobReport['objectStatus']))
            print('  Latest Run: %s' % usecsToDate(jobReport['objectLastRun']))
            for db in jobReport['dbList']:
                if (dbname is None) or (db['name'].lower() == dbname.lower()) or (db['name'].split('/')[-1].lower() == dbname.lower()):
                    print('     DB Name: %s (%s)' % (db['name'], db['status']))
                    dbReported = True

    if foundObject is False:
        print("None::Not Protected")
        exit(1)
    if dbname is not None and dbReported is False:
        print('%s Not Found on %s' % (dbname, objectname))
print('')
