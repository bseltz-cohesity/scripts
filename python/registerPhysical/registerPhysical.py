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
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--servername', action='append', type=str)  # server name to register
parser.add_argument('-l', '--serverlist', type=str, default=None)     # text list of servers to register
parser.add_argument('-r', '--reregister', action='store_true')
parser.add_argument('-f', '--force', action='store_true')
parser.add_argument('-t', '--throttle', type=int, default=0)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
mfacode = args.mfacode
emailmfacode = args.emailmfacode
servername = args.servername
serverlist = args.serverlist
force = args.force
throttle = args.throttle
reregister = args.reregister

# gather list function
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


# get list of views to protect
servernames = gatherList(servername, serverlist, name='servers', required=True)

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

forceRegister = False
if force is True:
    forceRegister = True

sources = api('get', 'protectionSources/registrationInfo?environments=kPhysical')

if throttle > 0:
    throttleParams = {
        "throttlingPolicy": {
            "isThrottlingEnabled": False
        },
        "physicalParams": {
            "sourceThrottlingConfig": {
                "cpuThrottlingConfig": None,
                "networkThrottlingConfig": {
                    "patternType": 1,
                    "fixedThreshold": throttle
                }
            }
        }
    }

for server in servernames:
    existingsourceId = None
    if sources is not None and 'rootNodes' in sources and sources['rootNodes'] is not None and len(sources['rootNodes']) > 0:
        existingsource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == server.lower()]
        if existingsource is not None and len(existingsource) > 0:
            existingsourceId = existingsource[0]['rootNode']['id']
        else:
            existingsourceId = None

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
        'sourceSideDedupEnabled': False,
        'throttlingPolicy': {
            'isThrottlingEnabled': False
        },
        'forceRegister': forceRegister
    }

    if reregister is True:
        newSource['reRegister'] = True

    if throttle > 0:
        newSource['registeredEntityParams'] = throttleParams

    if existingsourceId is None or reregister is True:
        result = api('post', '/backupsources', newSource)
        if result is not None:
            print("%s Registered" % server)
    else:
        result = api('put', '/backupsources/%s' % existingsourceId, newSource)
        print("%s Updated" % server)
