#!/usr/bin/env python
"""unprotect oracle"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-of', '--outfolder', type=str, default='.')

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
folder = args.outfolder

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

cluster = api('get', 'cluster')

now = datetime.now()
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/oracleLogDeletionDaysReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Job Name","Source Name","Databased Name","Log Deletion Days"\n')

jobs = api('get', 'data-protect/protection-groups?environments=kOracle&isActive=true&isDeleted=false', v=2)

if jobs['protectionGroups'] is None:
    print('no jobs found')
    exit(1)

sources = api('get', 'protectionSources?environments=kOracle')
if sources is None or len(sources) == 0 or 'nodes' not in sources[0] or len(sources[0]['nodes']) == 0:
    print('no registered oracle sources')
    exit(1)

objectName = {}
for thisSource in sources[0]['nodes']:
    for instance in thisSource['applicationNodes']:
        objectName["%s" % instance['protectionSource']['id']] = "%s/%s" % (thisSource['protectionSource']['name'], instance['protectionSource']['name'])

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    print('\n%s' % job['name'])
    for o in job['oracleParams']['objects']:
        for dbParam in o['dbParams']:
            logDeletionDays = 'n/a'
            if len(dbParam['dbChannels']) > 0:
                logDeletionDays = dbParam['dbChannels'][0]['archiveLogRetentionDays']
                if ("%s" % dbParam['databaseId']) in objectName.keys():
                    thisObject = objectName["%s" % dbParam['databaseId']]
                    (thisServer, thisDB) = thisObject.split('/')
            if ("%s" % dbParam['databaseId']) in objectName.keys():
                print("  %s: %s" % (objectName["%s" % dbParam['databaseId']], logDeletionDays))
                csv.write('"%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], thisServer, thisDB, logDeletionDays))
csv.close()
print('\nOutput saved to %s\n' % csvfileName)
