#!/usr/bin/env python
"""Protect Oracle Using Python"""

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
parser.add_argument('-jn', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)
parser.add_argument('-z', '--paused', action='store_true')
parser.add_argument('-ch', '--channels', type=int, default=None)
parser.add_argument('-cn', '--channelnode', action='append', type=str)
parser.add_argument('-cp', '--channelport', type=int, default=1521)
parser.add_argument('-l', '--deletelogdays', type=int)
parser.add_argument('-lh', '--deleteloghours', type=int)
parser.add_argument('-pm', '--persistmounts', action='store_true')

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
dbnames = args.dbname
dblist = args.dblist
jobname = args.jobname
storagedomain = args.storagedomain
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
paused = args.paused
channels = args.channels
channelnodes = args.channelnode
channelport = args.channelport
persistmounts = args.persistmounts
deletelogdays = args.deletelogdays
deleteloghours = args.deleteloghours

if channels is not None and channelnodes is None:
    print('channel node required if setting channels')
    exit()

if channelnodes is not None and channels is None:
    print('channels required if setting channel node')
    exit()


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

    job = {
        "name": jobname,
        "environment": "kOracle",
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
        "oracleParams": {
            "persistMountpoints": False,
            "objects": []
        }
    }

    if persistmounts:
        job['oracleParams']['persistMountpoints'] = True
    if paused is True:
        job['isPaused'] = True

else:
    job = job[0]

# get registered sql servers
sources = api('get', 'protectionSources?environments=kOracle')

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
        serverId = serverSource['protectionSource']['id']
        thisObject = [o for o in job['oracleParams']['objects'] if o['sourceId'] == serverId]
        job['oracleParams']['objects'] = [o for o in job['oracleParams']['objects'] if o['sourceId'] != serverId]
        if thisObject is None or len(thisObject) == 0:
            thisObject = {
                "sourceId": serverId,
                "dbParams": []
            }
        else:
            thisObject = thisObject[0]
        foundDBs = []
        for dbNode in serverSource['applicationNodes']:
            if len(dbnames) == 0 or dbNode['protectionSource']['name'].lower() in dbnames:
                foundDBs.append(dbNode['protectionSource']['name'].lower())
                print("Adding %s to %s" % (dbNode['protectionSource']['name'], jobname))
                thisDB = [o for o in thisObject['dbParams'] if o['databaseId'] == dbNode['protectionSource']['id']]
                thisObject['dbParams'] = [o for o in thisObject['dbParams'] if o['databaseId'] != dbNode['protectionSource']['id']]
                if thisDB is None or len(thisDB) == 0:
                    thisDB = {
                        "databaseId": dbNode['protectionSource']['id'],
                        "dbChannels": []
                    }
                else:
                    thisDB = thisDB[0]
                if (channels is not None and channelnodes is not None) or deletelogdays is not None or deleteloghours is not None:
                    thisDB['dbChannels'] = [
                        {
                            "databaseUuid": dbNode['protectionSource']['oracleProtectionSource']['uuid'],
                            "databaseNodeList": [],
                            "enableDgPrimaryBackup": True,
                            "rmanBackupType": "kImageCopy"
                        }
                    ]
                    if deletelogdays is not None:
                        thisDB['dbChannels'][0]['archiveLogRetentionDays'] = deletelogdays
                    elif deleteloghours is not None:
                        thisDB['dbChannels'][0]['archiveLogRetentionHours'] = deleteloghours
                    if (channels is not None and channelnodes is not None):
                        physicalSource = serverSource['protectionSource']['physicalProtectionSource']
                        if 'networkingInfo' in physicalSource:
                            serverResources = [r for r in physicalSource['networkingInfo']['resourceVec'] if r['type'] == 'kServer']
                        
                        for channelnode in channelnodes:
                            channelNodeObject = None
                            if 'networkingInfo' in physicalSource:
                                serverResources = [r for r in physicalSource['networkingInfo']['resourceVec'] if r['type'] == 'kServer']
                                for serverResource in serverResources:
                                    for endpoint in serverResource['endpoints']:
                                        if endpoint['fqdn'].lower() == channelnode.lower():
                                            matchingagents = [a for a in physicalSource['agents'] if a['name'].lower() == endpoint['fqdn'].lower()]
                                            if len(matchingagents) > 0:
                                                channelNodeObject = matchingagents[0]
                                                break
                                            elif 'ipv4Addr' in endpoint:
                                                matchingagents = [a for a in physicalSource['agents'] if a['name'].lower() == endpoint['ipv4Addr'].lower()]
                                                if len(matchingagents) > 0:
                                                    channelNodeObject = matchingagents[0]
                                                    break
                                            elif 'ipv6Addr' in endpoint:
                                                matchingagents = [a for a in physicalSource['agents'] if a['name'].lower() == endpoint['ipv6Addr'].lower()]
                                                if len(matchingagents) > 0:
                                                    channelNodeObject = matchingagents[0]
                                                    break
                            else:
                                for agent in physicalSource['agents']:
                                    if agent['name'].lower() == channelnode.lower():
                                        channelNodeObject = agent
                                        break
                            if channelNodeObject is None or len(channelNodeObject) == 0:
                                print("Channel node %s not found" % channelnode)
                                exit(1)
                            else:
                                channelNodeId = channelNodeObject['id']
                                thisDB['dbChannels'][0]['databaseNodeList'].append(
                                    {
                                        "hostId": str(channelNodeId),
                                        "channelCount": channels,
                                        "port": channelport
                                    }
                                )
                thisObject['dbParams'].append(thisDB)
            if len(dbnames) > 0:
                for dbname in dbnames:
                    if dbname.lower() not in foundDBs:
                        print('Database %s not found on server %s' % (dbname, server))
                        exit(1)
        if 'dbParams' not in thisObject or len(thisObject['dbParams']) == 0:
            print('No databases protected for server %s not found' % server)
            exit(1)
        job['oracleParams']['objects'].append(thisObject)

if newJob is True:
    print("Creating Job '%s'" % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print("Updating Job '%s'" % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
