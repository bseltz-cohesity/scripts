#!/usr/bin/env python
"""Protect Oracle"""

# usage:
# ./protectOracle.py -v mycluster \
#                    -u myuser \
#                    -d mydomain.net \
#                    -p 'My Policy' \
#                    -j 'My New Job' \
#                    -z 'America/New_York' \
#                    -s myserver.mydomain.net \
#                    -db mydb

# import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobname', type=str, required=True)   # name of protection job
parser.add_argument('-p', '--policyname', type=str)               # name of protection policy
parser.add_argument('-s', '--servername', action='append', type=str)  # name of server to protect
parser.add_argument('-f', '--serverlist', type=str)
parser.add_argument('-db', '--dbname', type=str)                    # name of DB to protect
parser.add_argument('-t', '--starttime', type=str, default='20:00')  # job start time
parser.add_argument('-z', '--timezone', type=str, default='America/Los_Angeles')  # timezone for job
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')  # storage domain
parser.add_argument('-l', '--deletelogdays', type=int, default=None)
parser.add_argument('-pause', '--pause', action='store_true')
parser.add_argument('-np', '--nopersistmounts', action='store_true')
parser.add_argument('-pm', '--persistmounts', action='store_true')

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
jobname = args.jobname
policyname = args.policyname
servername = args.servername
serverlist = args.serverlist
dbname = args.dbname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
storagedomain = args.storagedomain
deletelogdays = args.deletelogdays
pause = args.pause
nopersistmounts = args.nopersistmounts
persistmounts = args.persistmounts


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


servernames = gatherList(servername, serverlist, name='servers', required=True)

# parse starttime
try:
    (hour, minute) = starttime.split(':')
except Exception:
    print('starttime is invalid!')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# find storage domain
sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
if len(sd) < 1:
    print("Storage domain %s not found!" % storagedomain)
    exit(1)
sdid = sd[0]['id']

# get oracle sources
sources = api('get', 'protectionSources?environments=kOracle')

# find policy
if policyname is not None:
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print('Policy %s not found!' % policyname)
        exit(1)
    else:
        policy = policy[0]

# find existing job
newJob = False
job = [j for j in api('get', 'protectionJobs?environments=kOracle&isActive=true&isDeleted=false') if j['name'].lower() == jobname.lower()]
if len(job) < 1:
    if policyname is not None:
        newJob = True
        # create new job
        job = {
            "policyId": policy['id'],
            "viewBoxId": sdid,
            "createRemoteView": False,
            "priority": "kMedium",
            "incrementalProtectionSlaTimeMins": 60,
            "alertingPolicy": [
                "kFailure"
            ],
            "sourceSpecialParameters": [],
            "fullProtectionSlaTimeMins": 120,
            "timezone": timezone,
            "qosType": "kBackupHDD",
            "environment": "kOracle",
            "startTime": {
                "minute": int(minute),
                "hour": int(hour)
            },
            "parentSourceId": sources[0]['protectionSource']['id'],
            "name": jobname,
            "sourceIds": [],
            "indexingPolicy": {
                "disableIndexing": True
            },
            "environmentParameters": {
                "oracleParameters": {
                    "persistMountpoints": True
                }
            }
        }
    else:
        print('Job %s not found!' % jobname)
        exit(1)
else:
    job = job[0]

for sname in servernames:

    # find server to add to job
    server = [s for s in sources[0]['nodes'] if s['protectionSource']['name'].lower() == sname]
    if len(server) < 1:
        print('Server %s not found!' % sname)
        continue
    serverId = server[0]['protectionSource']['id']
    job['sourceIds'].append(serverId)

    if 'applicationNodes' not in server[0]:
        print('No databases found on %s' % sname)
        continue

    dbUuids = {}
    dbNames = {}
    for db in server[0]['applicationNodes']:
        dbUuids[db['protectionSource']['id']] = db['protectionSource']['oracleProtectionSource']['uuid']
        dbNames[db['protectionSource']['id']] = db['protectionSource']['name']

    if dbname is not None:
        # find db to add to job
        db = [a for a in server[0]['applicationNodes'] if a['protectionSource']['name'].lower() == dbname.lower()]
        if len(db) < 1:
            print('Database %s not found!' % dbname)
            continue
        dbIds = [db[0]['protectionSource']['id']]
        print('Adding %s/%s to protection job %s...' % (sname, dbname, jobname))
    else:
        # or add all dbs to job
        dbIds = [a['protectionSource']['id'] for a in server[0]['applicationNodes']]
        print('Adding %s/* to protection job %s...' % (sname, jobname))

    # update dblist for server
    sourceSpecialParameter = [s for s in job['sourceSpecialParameters'] if s['sourceId'] == serverId]
    if len(sourceSpecialParameter) < 1:
        job['sourceSpecialParameters'].append({"sourceId": serverId, "oracleSpecialParameters": {"applicationEntityIds": dbIds}})
        if deletelogdays is not None:
            sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'] = []
            for dbId in dbIds:
                sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'].append({
                    "databaseAppId": dbId,
                    "nodeChannelList": [
                        {
                            "databaseUuid": "%s" % dbUuids[dbId],
                            "databaseUniqueName": "%s" % dbNames[dbId],
                            "archiveLogKeepDays": deletelogdays,
                            "enableDgPrimaryBackup": True,
                            "rmanBackupType": 1
                        }
                    ]
                })
    else:
        for dbId in dbIds:
            sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds'].append(dbId)
            sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds'] = list(set(sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds']))
            if deletelogdays is not None:
                if 'appParamsList' not in sourceSpecialParameter[0]['oracleSpecialParameters']:
                    sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'] = []
                appParam = [a for a in sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'] if a['databaseAppId'] == dbId]
                otherAppParams = [a for a in sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'] if a['databaseAppId'] != dbId]
                if len(appParam) < 1:
                    sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'].append(
                        {
                            "databaseAppId": dbId,
                            "nodeChannelList": [
                                {
                                    "databaseUuid": "%s" % dbUuids[dbId],
                                    "databaseUniqueName": "%s" % dbNames[dbId],
                                    "archiveLogKeepDays": deletelogdays,
                                    "enableDgPrimaryBackup": True,
                                    "rmanBackupType": 1
                                }
                            ]
                        }
                    )
                else:
                    appParam[0] = {
                        "databaseAppId": dbId,
                        "nodeChannelList": [
                            {
                                "databaseUuid": "%s" % dbUuids[dbId],
                                "databaseUniqueName": "%s" % dbNames[dbId],
                                "archiveLogKeepDays": deletelogdays,
                                "enableDgPrimaryBackup": True,
                                "rmanBackupType": 1
                            }
                        ]
                    }
                    otherAppParams.append(appParam[0])
                    sourceSpecialParameter[0]['oracleSpecialParameters']['appParamsList'] = otherAppParams

job['sourceIds'] = list(set(job['sourceIds']))

if pause is True:
    job['isPaused'] = True

if nopersistmounts:
    if 'environmentParameters' not in job:
        job['environmentParameters'] = {
            "oracleParameters": {
                "persistMountpoints": False
            }
        }
    else:
        job['environmentParameters']['oracleParameters']['persistMountpoints'] = False
if persistmounts:
    job['environmentParameters']['oracleParameters']['persistMountpoints'] = True

if newJob is True:
    # create new job
    result = api('post', 'protectionJobs', job)
else:
    # update existing job
    result = api('put', 'protectionJobs/%s' % job['id'], job)
