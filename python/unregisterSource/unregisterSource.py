#!/usr/bin/env python
"""unprotect physical sources"""

# version 2024-11-02

# import pyhesity wrapper module
from pyhesity import *
from sys import exit
from time import sleep

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
parser.add_argument('-n', '--sourcename', action='append', type=str)
parser.add_argument('-l', '--sourcelist', type=str)
parser.add_argument('-s', '--sleepseconds', type=int, default=30)
parser.add_argument('-r', '--retries', type=int, default=10)

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
sleepseconds = args.sleepseconds
retries = args.retries


# gather source list
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


sourcenames = gatherList(sourcenames, sourcelist, name='jobs', required=True)

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

sourcefound = {}
for source in sourcenames:
    sourcefound[source] = False

sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false')
exitcode = 0

for source in sourcenames:
    thissource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == source.lower()]
    if thissource is not None and len(thissource) > 0:
        thisError = 0
        thissource = thissource[0]
        thissourcename = thissource['rootNode']['name']
        thissourceid = thissource['rootNode']['id']
        if thissourcename.lower() == source.lower():
            sourcefound[source] = True
            theseretries = retries + 1
            while theseretries > 0:
                print('Unregistering %s' % thissourcename)
                result = api('delete', 'protectionSources/%s' % thissourceid)
                if 'error' in result:
                    thisError = 1
                else:
                    thisError = 0
                if 'error' in result and 'is using it and is active' not in result['error']:
                    theseretries = theseretries - 1
                    if theseretries == 0:
                        break
                    print('--- retries: %s - sleeping for %s seconds' % (theseretries, sleepseconds))
                    sleep(sleepseconds)
                else:
                    break
            if thisError == 1:
                exitcode = 1
for source in sourcenames:
    if sourcefound[source] is False:
        print('%s not found' % source)
        exitcode = 1
exit(exitcode)
