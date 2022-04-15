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
parser.add_argument('-j', '--jobname', type=str, required=True)   # name of protection job
parser.add_argument('-p', '--policyname', type=str)               # name of protection policy
parser.add_argument('-s', '--servername', type=str, required=True)  # name of server to protect
parser.add_argument('-db', '--dbname', type=str)                    # name of DB to protect
parser.add_argument('-t', '--starttime', type=str, default='20:00')  # job start time
parser.add_argument('-z', '--timezone', type=str, default='America/Los_Angeles')  # timezone for job
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')  # storage domain

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
jobname = args.jobname
policyname = args.policyname
servername = args.servername
dbname = args.dbname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
storagedomain = args.storagedomain

# parse starttime
try:
    (hour, minute) = starttime.split(':')
except Exception:
    print('starttime is invalid!')
    exit(1)

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

### if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

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
            }
        }
    else:
        print('Job %s not found!' % jobname)
        exit(1)
else:
    job = job[0]

# find server to add to job
server = [s for s in sources[0]['nodes'] if s['protectionSource']['name'].lower() == servername]
if len(server) < 1:
    print('Server %s not found!' % servername)
    exit(1)
serverId = server[0]['protectionSource']['id']
job['sourceIds'].append(serverId)

if dbname is not None:
    # find db to add to job
    db = [a for a in server[0]['applicationNodes'] if a['protectionSource']['name'].lower() == dbname.lower()]
    if len(db) < 1:
        print("Database %s not found!" % dbname)
        exit(1)
    dbIds = [db[0]['protectionSource']['id']]
    print('Adding %s/%s to protection job %s...' % (servername, dbname, jobname))
else:
    # or add all dbs to job
    dbIds = [a['protectionSource']['id'] for a in server[0]['applicationNodes']]
    print('Adding %s/* to protection job %s...' % (servername, jobname))

# update dblist for server
sourceSpecialParameter = [s for s in job['sourceSpecialParameters'] if s['sourceId'] == serverId]
if len(sourceSpecialParameter) < 1:
    job['sourceSpecialParameters'].append({"sourceId": serverId, "oracleSpecialParameters": {"applicationEntityIds": dbIds}})
else:
    for dbId in dbIds:
        sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds'].append(dbId)
        sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds'] = list(set(sourceSpecialParameter[0]['oracleSpecialParameters']['applicationEntityIds']))
job['sourceIds'] = list(set(job['sourceIds']))

if newJob is True:
    # create new job
    result = api('post', 'protectionJobs', job)
else:
    # update existing job
    result = api('put', 'protectionJobs/%s' % job['id'], job)
