#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-st', '--starttime', type=str, default=None)
parser.add_argument('-et', '--endtime', type=str, default=None)
parser.add_argument('-end', '--endnow', action='store_true')
parser.add_argument('-start', '--startnow', action='store_true')

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
startnow = args.startnow
endnow = args.endnow
starttime = args.starttime
endtime = args.endtime

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

sourcenames = gatherList(sourcenames, sourcelist, name='jobs', required=True)

startmaintenance = False
endmaintenance = False

if startnow is True:
    startmaintenance = True
starttimeusecs = dateToUsecs()
if starttime is not None:
    startmaintenance = True
    starttimeusecs = dateToUsecs(starttime)

endtimeusecs = -1
if endtime is not None:
    startmaintenance = True
    endtimeusecs = dateToUsecs(endtime)

if endnow is True:
    endmaintenance = True

if endmaintenance is False and startmaintenance is False:
    print('No action specified')
    exit()

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

sources = api('get', 'protectionSources/registrationInfo?useCachedData=false&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false')
for sourcename in sourcenames:
    source = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == sourcename.lower()]
    if len(source) == 0:
        print('Source %s not found' % sourcename)
        exit(1)
    else:
        for thissource in source:
            metaupdate = False
            if startmaintenance is True:
                print('Scheduling maintenance on %s' % thissource['rootNode']['name'])
                maintenanceparams = {
                    "sourceId": thissource['rootNode']['id'],
                    "entityList": [
                        {
                            "entityId": thissource['rootNode']['id'],
                            "maintenanceModeConfig": {
                                "userMessage": "test",
                                "workflowInterventionSpecList": [
                                    {
                                        "workflowType": "BackupRun",
                                        "intervention": "Cancel"
                                    }
                                ],
                                "activationTimeIntervals": [
                                    {
                                        "startTimeUsecs": starttimeusecs,
                                        "endTimeUsecs": endtimeusecs
                                    }
                                ]
                            }
                        }
                    ]
                }
                metaupdate = True
            elif endmaintenance is True:
                print('Ending maintenance on %s' % thissource['rootNode']['name'])
                maintenanceparams = {
                    "sourceId": thissource['rootNode']['id'],
                    "entityList": [
                        {
                            "entityId": thissource['rootNode']['id'],
                            "maintenanceModeConfig": {}
                        }
                    ]
                }
                metaupdate = True
            if metaupdate is True:
                result = api('put', 'data-protect/objects/metadata', maintenanceparams, v=2)
