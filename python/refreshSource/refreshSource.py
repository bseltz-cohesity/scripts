#!/usr/bin/env python
"""refresh protection source"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
from sys import exit

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
parser.add_argument('-n', '--sourcename', type=str, action='append')   # optional name of vcenter
parser.add_argument('-l', '--sourcelist', type=str)
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
sourcenames = args.sourcename
sourcelist = args.sourcelist


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


sourceNames = gatherList(sourcenames, sourcelist, name='sources', required=True)

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

if sourceNames is None:
    print('No sources specified')
    exit()

sources = api('get', 'protectionSources/registrationInfo?allUnderHierarchy=false')
if 'rootNodes' not in sources:
    print('No sources found')
    exit()


def getObjectId(sourcename):
    for source in sources['rootNodes']:
        if source['rootNode']['name'].lower() == sourcename.lower():
            return source['rootNode']['id']
    return None


def waitForRefresh(sourcename):
    authStatus = ''
    while authStatus != 'Finished':
        rootFinished = False
        appsFinished = False
        sleep(5)
        rootNodes = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false')
        rootNode = [r for r in rootNodes['rootNodes'] if r['rootNode']['name'].lower() == sourcename.lower()]
        if rootNode[0]['registrationInfo']['authenticationStatus'] == 'kFinished':
            rootFinished = True
        if 'registeredAppsInfo' in rootNode[0]['registrationInfo']:
            for app in rootNode[0]['registrationInfo']['registeredAppsInfo']:
                if app['authenticationStatus'] == 'kFinished':
                    appsFinished = True
                else:
                    appsFinished = False
        else:
            appsFinished = True
        if rootFinished is True and appsFinished is True:
            authStatus = 'Finished'


for sourcename in sourceNames:
    objectId = getObjectId(sourcename)
    if objectId is not None:
        print('refreshing %s...' % sourcename)
        result = api('post', 'protectionSources/refresh/%s' % objectId)
        result = waitForRefresh(sourcename)
    else:
        print('%s not found' % sourcename)
