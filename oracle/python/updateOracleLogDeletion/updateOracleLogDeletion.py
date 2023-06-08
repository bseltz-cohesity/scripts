#!/usr/bin/env python
"""unprotect oracle"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-jn', '--jobname', action='append', type=str)
parser.add_argument('-jl', '--joblist', type=str)
parser.add_argument('-sn', '--servername', action='append', type=str)
parser.add_argument('-sl', '--serverlist', type=str)
parser.add_argument('-dn', '--dbname', action='append', type=str)
parser.add_argument('-dl', '--dblist', type=str)
parser.add_argument('-y', '--days', type=int, default=1)

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
jobnames = args.jobname
joblist = args.joblist
servernames = args.servername
serverlist = args.serverlist
dbnames = args.dbname
dblist = args.dblist
days = args.days

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


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)
servernames = gatherList(servernames, serverlist, name='servers', required=True)
dbnames = gatherList(dbnames, dblist, name='databases', required=False)

jobs = api('get', 'data-protect/protection-groups?environments=kOracle&isActive=true&isDeleted=false', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if jobs['protectionGroups'] is None:
    print('no jobs found')
    exit(1)

sources = api('get', 'protectionSources?environments=kOracle')
if sources is None or len(sources) == 0 or 'nodes' not in sources[0] or len(sources[0]['nodes']) == 0:
    print('no registered oracle sources')
    exit(1)

for thisServer in servernames:
    idsToUpdate = []
    objectName = {}
    noUpdates = True
    thisSource = [s for s in sources[0]['nodes'] if s['protectionSource']['name'].lower() == thisServer.lower()]
    if thisSource is None or len(thisSource) == 0:
        print('Server %s not found' % thisServer)
        exit(1)
    for instance in thisSource[0]['applicationNodes']:
        if len(dbnames) == 0 or instance['protectionSource']['name'].lower() in [n.lower() for n in dbnames]:
            idsToUpdate.append(instance['protectionSource']['id'])
            objectName["%s" % instance['protectionSource']['id']] = "%s/%s" % (thisSource[0]['protectionSource']['name'], instance['protectionSource']['name'])

    for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
        updatingJob = False
        if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
            for o in job['oracleParams']['objects']:
                for dbParam in o['dbParams']:
                    if dbParam['databaseId'] in idsToUpdate:
                        noUpdates = False
                        updatingJob = True
                        dbParam['dbChannels'][0]['archiveLogRetentionDays'] = days
                        print("Updating %s in %s" % (objectName["%s" % dbParam['databaseId']], job['name']))
            if updatingJob is True:
                # pass
                result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
    if noUpdates is True:
        print('no databases to update on %s' % thisServer)
