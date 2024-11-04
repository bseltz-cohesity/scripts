#!/usr/bin/env python
"""Protect SQL Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
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
parser.add_argument('-sn', '--servername', action='append', type=str)
parser.add_argument('-sl', '--serverlist', type=str)
parser.add_argument('-dn', '--dbname', action='append', type=str)
parser.add_argument('-dl', '--dblist', type=str)
parser.add_argument('-in', '--instancename', action='append', type=str)
parser.add_argument('-jn', '--jobname', type=str, default=None)
parser.add_argument('-b', '--backuptype', type=str, choices=['File', 'Volume', 'VDI'], default='File')
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-z', '--paused', action='store_true')
parser.add_argument('-n', '--numstreams', type=int, default=3)
parser.add_argument('-l', '--logstreams', type=int, default=3)
parser.add_argument('-wc', '--withclause', type=str, default='')
parser.add_argument('-lc', '--logclause', type=str, default='')
parser.add_argument('-ssd', '--sourcesidededuplication', action='store_true')
parser.add_argument('-o', '--instancesonly', action='store_true')
parser.add_argument('-so', '--systemdbsonly', action='store_true')
parser.add_argument('-a', '--alldbs', action='store_true')
parser.add_argument('-s', '--showunprotecteddbs', action='store_true')
parser.add_argument('-ud', '--unprotecteddbs', action='store_true')
parser.add_argument('-r', '--replace', action='store_true')

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
servernames = args.servername
serverlist = args.serverlist
instancenames = args.instancename
dbnames = args.dbname
dblist = args.dblist
jobname = args.jobname
backuptype = args.backuptype
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
paused = args.paused
numstreams = args.numstreams
logstreams = args.logstreams
withclause = args.withclause
logclause = args.logclause
sourcesidededuplication = args.sourcesidededuplication
instancesonly = args.instancesonly
systemdbsonly = args.systemdbsonly
unprotecteddbs = args.unprotecteddbs
replace = args.replace
alldbs = args.alldbs
showunprotecteddbs = args.showunprotecteddbs


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


servernames = gatherList(servernames, serverlist, name='servers', required=False)
dbnames = gatherList(dbnames, dblist, name='databases', required=False)

if jobname is None and showunprotecteddbs is not True:
    print('-j, --jobname is required')
    exit()

if instancenames is None:
    instancenames = []

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

# get job info
if showunprotecteddbs is not True:
    newJob = False
    protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
    jobs = protectionGroups['protectionGroups']
    job = [job for job in jobs if job['name'].lower() == jobname.lower()]

    if not job or len(job) < 1:
        newJob = True

        # find protectionPolicy
        if policyname is None:
            print('Policy name required for new job')
            exit(1)
        policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
        if len(policy) < 1:
            print("Policy '%s' not found!" % policyname)
            exit(1)
        policyid = policy[0]['id']

        # find storage domain
        sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
        if len(sd) < 1:
            print("Storage domain %s not found!" % storagedomain)
            exit(1)
        sdid = sd[0]['id']

        # parse starttime
        try:
            (hour, minute) = starttime.split(':')
            hour = int(hour)
            minute = int(minute)
            if hour < 0 or hour > 23 or minute < 0 or minute > 59:
                print('starttime is invalid!')
                exit(1)
        except Exception:
            print('starttime is invalid!')
            exit(1)

        backupTypeEnum = {
            'File': 'kFile',
            'Volume': 'kVolume',
            'VDI': 'kNative'
        }

        job = {
            "name": jobname,
            "environment": "kSQL",
            "isPaused": False,
            "policyId": policyid,
            "priority": "kMedium",
            "storageDomainId": sdid,
            "description": "",
            "startTime": {
                "hour": hour,
                "minute": minute,
                "timeZone": timezone
            },
            "abortInBlackouts": False,
            "alertPolicy": {
                "backupRunStatus": [
                    "kFailure"
                ],
                "alertTargets": []
            },
            "sla": [
                {
                    "backupRunType": "kFull",
                    "slaMinutes": fullsla
                },
                {
                    "backupRunType": "kIncremental",
                    "slaMinutes": incrementalsla
                }
            ],
            "qosPolicy": "kBackupHDD",
            "mssqlParams": {
                "protectionType": backupTypeEnum[backuptype]
            }
        }

        if paused is True:
            job['isPaused'] = True

        if backuptype == 'File':
            job['mssqlParams']['fileProtectionTypeParams'] = {
                "objects": [],
                "performSourceSideDeduplication": False,
                "additionalHostParams": [],
                "userDbBackupPreferenceType": "kBackupAllDatabases",
                "backupSystemDbs": True,
                "useAagPreferencesFromServer": True,
                "fullBackupsCopyOnly": False,
                "excludeFilters": None,
                "logBackupNumStreams": logstreams,
                "logBackupWithClause": logclause
            }

            if sourcesidededuplication is True:
                job['mssqlParams']['fileProtectionTypeParams']['performSourceSideDeduplication'] = True
            params = job['mssqlParams']['fileProtectionTypeParams']

        if backuptype == 'VDI':
            job['mssqlParams']['nativeProtectionTypeParams'] = {
                "objects": [],
                "numStreams": numstreams,
                "withClause": withclause,
                "logBackupNumStreams": logstreams,
                "logBackupWithClause": logclause,
                "userDbBackupPreferenceType": "kBackupAllDatabases",
                "backupSystemDbs": True,
                "useAagPreferencesFromServer": True,
                "fullBackupsCopyOnly": False,
                "excludeFilters": None
            }
            params = job['mssqlParams']['nativeProtectionTypeParams']

        if backuptype == 'Volume':
            job['mssqlParams']['volumeProtectionTypeParams'] = {
                "objects": [],
                "logBackupNumStreams": logstreams,
                "logBackupWithClause": logclause,
                "incrementalBackupAfterRestart": True,
                "indexingPolicy": {
                    "enableIndexing": True,
                    "includePaths": [
                        "/"
                    ],
                    "excludePaths": [
                        '/$Recycle.Bin',
                        "/Windows",
                        "/Program Files",
                        "/Program Files (x86)",
                        "/ProgramData",
                        "/System Volume Information",
                        "/Users/*/AppData",
                        "/Recovery",
                        "/var",
                        "/usr",
                        "/sys",
                        "/proc",
                        "/lib",
                        "/grub",
                        "/grub2",
                        "/opt/splunk",
                        "/splunk"
                    ]
                },
                "backupDbVolumesOnly": False,
                "additionalHostParams": [],
                "userDbBackupPreferenceType": "kBackupAllDatabases",
                "backupSystemDbs": True,
                "useAagPreferencesFromServer": True,
                "fullBackupsCopyOnly": False,
                "excludeFilters": None
            }
            params = job['mssqlParams']['volumeProtectionTypeParams']

    else:
        job = job[0]
        if job['mssqlParams']['protectionType'] == 'kFile':
            params = job['mssqlParams']['fileProtectionTypeParams']
            params['logBackupNumStreams'] = logstreams
            if logclause != '':
                params['logBackupWithClause'] = logclause

        if job['mssqlParams']['protectionType'] == 'kNative':
            params = job['mssqlParams']['nativeProtectionTypeParams']
            params['numStreams'] = numstreams
            if withclause != '':
                params['withClause'] = withclause
            params['logBackupNumStreams'] = logstreams
            if logclause != '':
                params['logBackupWithClause'] = logclause

        if job['mssqlParams']['protectionType'] == 'kVolume':
            params = job['mssqlParams']['volumeProtectionTypeParams']
            params['logBackupNumStreams'] = logstreams
            if logclause != '':
                params['logBackupWithClause'] = logclause


def clearSelection(thisSource):
    params['objects'] = [o for o in params['objects'] if o['id'] != thisSource['protectionSource']['id']]
    if 'applicationNodes' in thisSource:
        for instance in thisSource['applicationNodes']:
            params['objects'] = [o for o in params['objects'] if o['id'] != instance['protectionSource']['id']]
            if 'nodes' in instance:
                for db in instance['nodes']:
                    params['objects'] = [o for o in params['objects'] if o['id'] != db['protectionSource']['id']]
    if 'nodes' in thisSource:
        for db in thisSource['nodes']:
            params['objects'] = [o for o in params['objects'] if o['id'] != db['protectionSource']['id']]


def addSelection(thisSource):
    params['objects'] = [o for o in params['objects'] if o['id'] != thisSource['protectionSource']['id']]
    params['objects'].append({'id': thisSource['protectionSource']['id']})
    if 'applicationNodes' in thisSource:
        for instance in thisSource['applicationNodes']:
            params['objects'] = [o for o in params['objects'] if o['id'] != instance['protectionSource']['id']]
            if 'nodes' in instance:
                for db in instance['nodes']:
                    params['objects'] = [o for o in params['objects'] if o['id'] != db['protectionSource']['id']]
    if 'nodes' in thisSource:
        for db in thisSource['nodes']:
            params['objects'] = [o for o in params['objects'] if o['id'] != db['protectionSource']['id']]


def isSelected(thisSource):
    existingSelection = [o for o in params['objects'] if o['id'] == thisSource['protectionSource']['id']]
    if existingSelection is not None and len(existingSelection) > 0:
        return True
    return False


def showUnprotected(serverSource):
    print('\n%s\n' % serverSource['protectionSource']['name'])
    allProtected = True
    for instanceSource in sorted(serverSource['applicationNodes'], key=lambda instanceSource: instanceSource['protectionSource']['name']):
        if len(instancenames) == 0 or instanceSource['protectionSource']['name'].lower() in [n.lower() for n in instancenames]:
            for dbSource in sorted(instanceSource['nodes'], key=lambda dbSource: dbSource['protectionSource']['name']):
                if 'leavesCount' in dbSource['unprotectedSourcesSummary'][0] and dbSource['unprotectedSourcesSummary'][0]['leavesCount'] > 0:
                    print('    %s (unprotected)' % dbSource['protectionSource']['name'])
                    allProtected = False
    if allProtected is True:
        print('    ALL PROTECTED')


# get registered sql servers
sources = api('get', 'protectionSources?environments=kSQL')
systemDBs = ['master', 'model', 'msdb']
if len(dbnames) > 0:
    dbnames = [d.lower() for d in dbnames]
# server source
for server in servernames:
    serverSource = [n for n in sources[0]['nodes'] if n['protectionSource']['name'].lower() == server.lower()]
    if serverSource is None or len(serverSource) == 0:
        print("Server %s not found!" % server)
        exit(1)
    else:
        serverSource = serverSource[0]
    if showunprotecteddbs is True:
        showUnprotected(serverSource)
        continue
    if replace is True:
        clearSelection(serverSource)
    if len(instancenames) == 0 and instancesonly is True:
        print("Protecting %s" % server)
        for instanceSource in serverSource['applicationNodes']:
            if not isSelected(serverSource):
                addSelection(instanceSource)
    elif len(instancenames) > 0 and len(dbnames) == 0:
        for instance in instancenames:
            print("Protecting %s/%s" % (server, instance))
            if isSelected(serverSource):
                break
            instanceSource = [n for n in serverSource['applicationNodes'] if n['protectionSource']['name'].lower() == instance.lower()]
            if instanceSource is None or len(instanceSource) == 0:
                print("Instance %s not found on server %s" % (instance, server))
                exit(1)
            else:
                instanceSource = instanceSource[0]
                if systemdbsonly is True:
                    if not isSelected(instanceSource) and not isSelected(serverSource):
                        for db in instanceSource['nodes']:
                            if db['protectionSource']['name'].split('/')[1] in systemDBs:
                                addSelection(db)
                elif alldbs:
                    if not isSelected(instanceSource) and not isSelected(serverSource):
                        for db in instanceSource['nodes']:
                            addSelection(db)
                else:
                    addSelection(instanceSource)
    else:
        if systemdbsonly is True:
            for instanceSource in serverSource['applicationNodes']:
                if len(instancenames) == 0 or instanceSource['protectionSource']['name'].lower() in instancenames:
                    for node in instanceSource['nodes']:
                        if node['protectionSource']['name'].lower().split('/')[1] in systemDBs:
                            if not isSelected(instanceSource):
                                addSelection(node)
                    print("Protecting %s/%s System DBs" % (server, instanceSource['protectionSource']['name']))
        elif alldbs is True:
            print("Protecting %s" % server)
            for instanceSource in serverSource['applicationNodes']:
                if not isSelected(instanceSource) and not isSelected(serverSource):
                    for node in instanceSource['nodes']:
                        addSelection(node)
        elif unprotecteddbs is True:
            for instanceSource in serverSource['applicationNodes']:
                for node in instanceSource['nodes']:
                    if node['unprotectedSourcesSummary'][0]['leavesCount'] == 1:
                        if not isSelected(serverSource) and not isSelected(instanceSource):
                            addSelection(node)
            print("Protecting %s" % server)
        elif len(dbnames) > 0:
            if len(instancenames) == 0:
                instancenames = ['mssqlserver']
            instanceSources = [i for i in serverSource['applicationNodes'] if i['protectionSource']['name'].lower() in instancenames]
            for instanceSource in instanceSources:
                for thisDBName in dbnames:
                    dbSource = [d for d in instanceSource['nodes'] if d['protectionSource']['name'].lower() == "%s/%s" % (instanceSource['protectionSource']['name'].lower(), thisDBName.lower())]
                    if dbSource is None or len(dbSource) == 0:
                        print("%s not found in %s/%s" % (thisDBName, server, instanceSource['protectionSource']['name']))
                        continue
                    else:
                        dbSource = dbSource[0]
                    if not isSelected(serverSource) and not isSelected(instanceSource):
                        addSelection(dbSource)
                    print("Protecting %s/%s/%s" % (server, instanceSource['protectionSource']['name'], thisDBName))
        else:
            addSelection(serverSource)
            print("Protecting %s" % server)

if showunprotecteddbs is True:
    exit()

if len(params['objects']) == 0:
    print("Nothing protected")

if newJob is True:
    print("Creating Job '%s'" % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print("Updating Job '%s'" % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
