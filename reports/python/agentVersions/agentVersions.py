#!/usr/bin/env python
"""base V2 example"""

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
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-env', '--environment', type=str, default=None)

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
environment = args.environment

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode, tenantId=tenant)

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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'agentVersions-%s-%s.tsv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Cluster Name\tSource Name\tAgent Version\tOS Type\tOS Name\tApps\n')

nodes = api('get', 'protectionSources/registrationInfo?allUnderHierarchy=true')

for node in nodes['rootNodes']:
    psproperty = [p for p in node['rootNode'].keys() if 'ProtectionSource' in p]
    version = 'unknown'
    hostType = 'unknown'
    osName = 'unknown'
    apps = ''
    name = node['rootNode']['name']
    if 'agents' in node['rootNode'][psproperty[0]] and len(node['rootNode'][psproperty[0]]['agents']) > 0 and 'version' in node['rootNode'][psproperty[0]]['agents'][0]:
        version = node['rootNode'][psproperty[0]]['agents'][0]['version']
        hostType = node['rootNode'][psproperty[0]]['hostType'][1:]
        osName = node['rootNode'][psproperty[0]]['osName']
        if 'environments' in node['registrationInfo']:
            apps = node['registrationInfo']['environments']
        if environment is None or environment in apps:
            print('%s\t%s\t(%s) %s %s' % (name, version, hostType, osName, ','.join(apps)))
            f.write('%s\t%s\t%s\t%s\t%s\n' % (cluster['name'], name, version, hostType, osName))
f.close()
print('\nOutput saved to %s\n' % outfile)
