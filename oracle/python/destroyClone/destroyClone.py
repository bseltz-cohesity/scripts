#!/usr/bin/env python
"""Destroy Clone for python"""

### usage: ./destroyClone.py -v mycluster -u myuser -d mydomain.net -o devdb -s sqldev.mydomain.net -t sql -w

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-o', '--objectname', type=str, required=True)
parser.add_argument('-s', '--servername', type=str, default=None)
parser.add_argument('-i', '--instance', type=str, default='MSSQLSERVER')
parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-t', '--clonetype', type=str, choices=['sql', 'view', 'vm', 'oracle'], required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
objectname = args.objectname.lower()
servername = args.servername
instance = args.instance.lower()
wait = args.wait
clonetype = args.clonetype.lower()

# validate args
if clonetype == 'sql' or clonetype == 'oracle':
    if servername is None:
        print('servername parameter is required')
        exit(1)

cloneTypes = {
    'vm': 2,
    'view': 5,
    'sql': 7,
    'oracle': 7
}

taskId = None
deleteView = None

# authenticate
apiauth(vip, username, domain)

allclones = api('get', '/restoretasks?restoreTypes=kCloneView&restoreTypes=kConvertAndDeployVMs&restoreTypes=kCloneApp&restoreTypes=kCloneVMs')

availableclones = [clone for clone in allclones if
                   'destroyClonedTaskStateVec' not in clone['restoreTask'] and
                   clone['restoreTask']['performRestoreTaskState']['base']['type'] == cloneTypes[clonetype] and
                   clone['restoreTask']['performRestoreTaskState']['base']['publicStatus'] == 'kSuccess']

for clone in availableclones:
    thisTaskId = clone['restoreTask']['performRestoreTaskState']['base']['taskId']

    if clonetype == 'sql':
        cloneDB = clone['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['sqlRestoreParams']['newDatabaseName']
        cloneHost = clone['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['targetHost']['displayName']
        cloneInstance = clone['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['sqlRestoreParams']['instanceName']
        if cloneDB.lower() == objectname and cloneHost.lower() == servername.lower() and cloneInstance.lower() == instance:
            print('tearing down SQLDB: %s/%s from %s...' % (cloneInstance, cloneDB, cloneHost))
            taskId = thisTaskId
            break

    if clonetype == 'oracle':
        cloneDB = clone['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['oracleRestoreParams']['alternateLocationParams']['newDatabaseName']
        cloneHost = clone['restoreTask']['performRestoreTaskState']['restoreAppTaskState']['restoreAppParams']['restoreAppObjectVec'][0]['restoreParams']['targetHost']['displayName']
        if cloneDB.lower() == objectname and cloneHost.lower() == servername.lower():
            print('tearing down Oracle DB: %s from %s...' % (cloneDB, cloneHost))
            taskId = thisTaskId
            break

    if clonetype == 'view':
        cloneViewName = clone['restoreTask']['performRestoreTaskState']['fullViewName']
        if cloneViewName.lower() == objectname:
            print('tearing down View: %s' % cloneViewName)
            deleteView = cloneViewName
            break

    if clonetype == 'vm':
        for vm in clone['restoreTask']['performRestoreTaskState']['restoreInfo']['restoreEntityVec']:
            if vm['restoredEntity']['vmwareEntity']['name'].lower() == objectname:
                print('tearing down VM: %s...' % objectname)
                taskId = thisTaskId
                break

if deleteView is not None:
    result = api('delete', 'views/%s' % deleteView)

elif taskId is not None:
    result = api('post', '/destroyclone/%s' % taskId)

    if wait:
        finished = False
        while finished is False:
            sleep(3)
            result = api('get', '/restoretasks/%s' % taskId)

            if clonetype == 'sql' or clonetype == 'oracle':
                if 'destroyClonedTaskStateVec' in result[0]['restoreTask']:
                    if len(result[0]['restoreTask']['destroyClonedTaskStateVec']) > 0:
                        if 'finished' in result[0]['restoreTask']['destroyClonedTaskStateVec'][0]['destroyCloneAppTaskInfo']:
                            if result[0]['restoreTask']['destroyClonedTaskStateVec'][0]['destroyCloneAppTaskInfo']['finished'] is True:
                                finished = True

            elif clonetype == 'vm':
                if 'destroyClonedTaskStateVec' in result[0]['restoreTask']:
                    if len(result[0]['restoreTask']['destroyClonedTaskStateVec']) > 0:
                        if 'status' in result[0]['restoreTask']['destroyClonedTaskStateVec'][0]:
                            if result[0]['restoreTask']['destroyClonedTaskStateVec'][0]['status'] == 2:
                                finished = True

else:
    print('clone %s not found' % objectname)
