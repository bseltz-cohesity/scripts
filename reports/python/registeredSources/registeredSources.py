#!/usr/bin/env python
"""List Protected Objects for python"""

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

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

csvfileName = '%s/registeredSources.csv' % (folder)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Source Name","Environment","Protected Count","Unprotected Count"\n')
noSourcesFound = True

def report():

    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])
    sources = api('get', 'protectionSources/registrationInfo?includeApplicationsTreeInfo=false')
    for source in sorted(sources['rootNodes'], key=lambda node: node['rootNode']['name']):
        sourcename = source['rootNode']['name']
        if 'cassandraProtectionSource' in source['rootNode']:
            sourcename = source['rootNode']['cassandraProtectionSource']['uuid']
        environment = source['rootNode']['environment'][1:]
        protected = source['stats']['protectedCount']
        unprotected = source['stats']['unprotectedCount']
        if 'environments' in source['registrationInfo']:
            for env in source['registrationInfo']['environments']:
                environment = '%s/%s' % (environment, env[1:])
        print('    %s (%s)' % (sourcename, environment))
        csv.write('%s,%s,%s,%s,%s\n' % (cluster['name'], sourcename, environment, protected, unprotected))

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
print('\nOutput saved to %s\n' % csvfileName)
