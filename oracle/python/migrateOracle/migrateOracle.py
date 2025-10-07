#!/usr/bin/env python
"""Restore Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime, timedelta
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-y', '--days', type=int, default=31)
parser.add_argument('-n', '--dbname', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
days = args.days
dbname = args.dbname


# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

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

# date range calc
now = datetime.now()
dateString = dateToString(now, "%Y-%m-%d")

uStart = timeAgo(days, 'days')
uEnd = dateToUsecs(now)

start = usecsToDate(uStart, '%Y-%m-%d')
end = usecsToDate(uEnd, '%Y-%m-%d')

entityType = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer',
              'Physical', 'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas',
              'Acropolis', 'PhysicalFiles', 'Isilon', 'KVM', 'AWS', 'Exchange',
              'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
              'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative',
              'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Kubernetes',
              'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB',
              'HBase', 'Hive', 'Hdfs', 'Couchbase', 'Unknown', 'Unknown', 'Unknown']

foundRestore = False

restores = api('get', '/restoretasks?_includeTenantInfo=true&restoreTypes=kRestoreApp&endTimeUsecs=%s&startTimeUsecs=%s&targetType=kLocal' % (uEnd, uStart))
for restore in restores:
    taskId = restore['restoreTask']['performRestoreTaskState']['base']['taskId']
    taskName = restore['restoreTask']['performRestoreTaskState']['base']['name']
    status = restore['restoreTask']['performRestoreTaskState']['base']['publicStatus'][1:]
    startTime = usecsToDate(restore['restoreTask']['performRestoreTaskState']['base']['startTimeUsecs'])
    startTimeUsecs = restore['restoreTask']['performRestoreTaskState']['base']['startTimeUsecs']
    restoreUser = restore['restoreTask']['performRestoreTaskState']['base']['user']
    duration = '-'
    if 'endTimeUsecs' in restore['restoreTask']['performRestoreTaskState']['base']:
        endTime = usecsToDate(restore['restoreTask']['performRestoreTaskState']['base']['endTimeUsecs'])
        endTimeUsecs = restore['restoreTask']['performRestoreTaskState']['base']['endTimeUsecs']
        duration = round((endTimeUsecs - startTimeUsecs) / (60000000))

    if 'restoreAppTaskState' in restore['restoreTask']['performRestoreTaskState']:
        if restore['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['type'] != 19:
            continue
        targetServer = sourceServer = restore['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['ownerRestoreInfo']['ownerObject']['entity']['displayName']
        for restoreAppObject in restore['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec']:
            objectName = restoreAppObject['appEntity']['displayName']
            objectType = entityType[restoreAppObject['appEntity']['type']]
            if 'targetHost' in restoreAppObject['restoreParams']:
                if restoreAppObject['restoreParams']['targetHost']['displayName']:
                    targetServer = restoreAppObject['restoreParams']['targetHost']['displayName']
            targetObject = targetServer
            
            if 'oracleRestoreParams' in restoreAppObject['restoreParams']:
                if 'alternateLocationParams' in restoreAppObject['restoreParams']['oracleRestoreParams']:
                    if 'newDatabaseName' in restoreAppObject['restoreParams']['oracleRestoreParams']['alternateLocationParams']:
                        targetObject += '/%s' % restoreAppObject['restoreParams']['oracleRestoreParams']['alternateLocationParams']['newDatabaseName']
            if targetObject == targetServer:
                targetObject = '%s/%s' % (targetServer, objectName)
            if targetObject.lower() == dbname.lower():
                foundRestore = True
                migrateParams = {
                    "restoreTaskId": taskId,
                    "oracleOptions": {
                        "migrateCloneParams": {
                            "delaySecs": 0,
                            "targetPathVec": [
                                ""
                            ]
                        }
                    }
                }
                result = api('put', 'restore/recover', migrateParams)
                if result is None or 'error' not in result:
                    print('migrating %s' % targetObject)              
                exit()
print('no matching restore found')
