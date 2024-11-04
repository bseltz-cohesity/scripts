#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-s', '--servername', action='append', type=str)  # server name to register
parser.add_argument('-l', '--serverlist', type=str, default=None)     # text list of servers to register

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
servernames = args.servername
serverlist = args.serverlist

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

# read server file
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

# get protection sources
oracleSources = api('get', 'protectionSources?environments=kOracle')
phys = api('get', 'protectionSources?environments=kPhysical')

for server in servernames:

    existingsource = [s for s in phys[0]['nodes'] if s['protectionSource']['name'].lower() == server.lower()]
    if len(existingsource) == 0:
        newSource = {
            'entity': {
                'type': 6,
                'physicalEntity': {
                    'name': server,
                    'type': 1,
                    'hostType': 1
                }
            },
            'entityInfo': {
                'endpoint': server,
                'type': 6,
                'hostType': 1
            },
            'sourceSideDedupEnabled': True,
            'throttlingPolicy': {
                'isThrottlingEnabled': False
            },
            'forceRegister': True
        }

        result = api('post', '/backupsources', newSource)

        sourceId = None
        if result is not None:
            sourceId = result['entity']['id']
    else:
        sourceId = existingsource[0]['protectionSource']['id']

    if sourceId is not None:
        # see if server is already registered as Oracle
        if oracleSources is not None and len(oracleSources) > 0:
            existingOracleSource = [o for o in oracleSources[0]['nodes'] if o['protectionSource']['id'] == sourceId]
            if len(existingOracleSource) > 0:
                print("%s is already registered as an Oracle protection source" % server)
                exit()

        # register server as Oracle
        print("Registering %s as an Oracle protection source..." % server)
        regOracle = {"ownerEntity": {"id": sourceId}, "appEnvVec": [19]}
        result = api('post', '/applicationSourceRegistration', regOracle)

    else:
        print("failed to register %s" % server)
