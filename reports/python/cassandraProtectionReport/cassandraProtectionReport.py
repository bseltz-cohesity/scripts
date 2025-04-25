#!/usr/bin/env python

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
folder = args.outfolder

scriptVersion = '2025-04-03 (Python)'

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

csvfileName = '%s/cassandraProtectionReport.csv' % (folder)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Source Name","KeySpace Name","Table Name","Protected","Protection Group"\n')
noSourcesFound = True

def report():
    # global csv
    global noSourcesFound
    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])
    sources = api('get', 'protectionSources/registrationInfo?useCachedData=false&pruneNonCriticalInfo=true&allUnderHierarchy=true&includeExternalMetadata=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false&environments=kCassandra')
    if 'rootNodes' in sources and sources['rootNodes'] is not None:
        for source in sources['rootNodes']:
            noSourcesFound = False
            sourceName = source['rootNode']['cassandraProtectionSource']['uuid']
            print('    %s' % sourceName)
            thisSource = api('get', 'protectionSources?_useClientSideExcludeTypesFilter=false&allUnderHierarchy=true&id=%s&includeEntityPermissionInfo=true' % source['rootNode']['id'])
            protectedObjects = api('get', 'protectionSources/protectedObjects?environment=kCassandra&id=%s&includeRpoSnapshots=false&pruneProtectionJobMetadata=true' % source['rootNode']['id'])
            if 'nodes' in thisSource[0]:
                for keyspace in thisSource[0]['nodes']:
                    keySpaceName = keyspace['protectionSource']['cassandraProtectionSource']['name']
                    if 'nodes' in keyspace:
                        for table in keyspace['nodes']:
                            protected = False
                            protectionJob = ''
                            tableName = table['protectionSource']['cassandraProtectionSource']['name']
                            protectedObject = [o for o in protectedObjects if o['protectionSource']['id'] == table['protectionSource']['id']]
                            if protectedObject is not None and len(protectedObject) > 0:
                                protected = True
                                protectionJob = protectedObject[0]['protectionJobs'][0]['name']
                            csv.write('"%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], sourceName, keySpaceName, tableName, protected, protectionJob))

for vip in vips:

    # authentication =========================================================
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

    # exit if not authenticated
    if apiconnected() is False:
        print('authentication failed')
        continue

    # if connected to helios or mcm, select access cluster
    if mcm or vip.lower() == 'helios.cohesity.com':
        if clusternames is None or len(clusternames) == 0:
            clusternames = [c['name'] for c in heliosClusters()]
        for clustername in clusternames:
            heliosCluster(clustername)
            if LAST_API_ERROR() != 'OK':
                continue
            report()
    else:
        report()

csv.close()
print('\nOutput saved to: %s\n' % csvfileName)
