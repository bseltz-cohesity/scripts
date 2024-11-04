#!/usr/bin/env python
"""Show Object Protection Status"""

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
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-o', '--object', type=str, required=True)

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
objectname = args.object

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, quiet=True)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

sources = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false&allUnderHierarchy=true&environments=kPhysical')

foundObject = False
jobs = []
jobnames = []
objectId = None

if sources is None or 'rootNodes' not in sources or sources['rootNodes'] is None:
    print("None")
    exit(1)

for rootNode in sources['rootNodes']:
    parentId = rootNode['rootNode']['id']
    parentName = rootNode['rootNode']['name']
    if parentName.lower() == objectname.lower():
        foundObject = True
        objectId = parentId
    protectedSources = api('get', 'protectionSources/protectedObjects?id=%s&environment=kPhysical' % parentId)
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
        if foundObject is True:
            break
    if foundObject is True:
        break

jobReports = []

if objectId is None:
    print("None")
    exit(1)
else:
    foundProtectedObject = False
    objectJobIDs = []
    for job in jobs:
        environment = job['environment']
        parentId = job['parentSourceId']

        sourceIds = job.get('sourceIds', [])

        protectedObjects = api('get', 'protectionSources/protectedObjects?environment=%s&id=%s' % (environment, parentId))
        protectedObjects = [o for o in protectedObjects if o['protectionSource']['id'] == objectId]
        for protectedObject in protectedObjects:
            for protectionJob in protectedObject['protectionJobs']:
                objectJobIDs.append(protectionJob['id'])

    if len(objectJobIDs) == 0:
        print("None")
        exit(1)
    else:
        for job in [j for j in jobs if j['id'] in objectJobIDs]:
            foundProtectedObject = True
            jobName = job['name']
            jobType = job['environment'][1:]
            jobReport = {'jobName': jobName, 'jobType': jobType, 'dbList': [], 'objectStatus': 'Protected', 'objectLastRun': 0}
            jobReports.append(jobReport)

    foundObject = False
    dbReported = False
    for jobReport in jobReports:
        foundObject = True
        print('%s' % jobReport['jobName'])

    if foundObject is False:
        print("None")
        exit(1)

exit(0)
