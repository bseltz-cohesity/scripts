#!/usr/bin/env python
"""List Recovery Points for python"""

### usage: ./recoveryPoints.py -v mycluster -u admin [-d local]

### import pyhesity wrapper module
from pyhesity import *
import codecs
import os

### command line arguments
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
parser.add_argument('-n', '--pagesize', type=int, default=1000)
parser.add_argument('-y', '--days', type=int, default=None)
parser.add_argument('-e', '--environment', type=str, action='append')
parser.add_argument('-x', '--excludeenvironment', type=str, action='append')
parser.add_argument('-o', '--outputpath', type=str, default='.')
parser.add_argument('-l', '--localonly', action='store_true')

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
pagesize = args.pagesize
days = args.days
environment = args.environment
excludeenvironment = args.excludeenvironment
outputpath = args.outputpath
localonly = args.localonly

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

environments = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer', 'Physical',
                'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade',
                'AWSNative', 'VCD', 'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative',
                'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Unknown', 'Kubernetes',
                'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB', 'HBase',
                'Hive', 'Hdfs', 'Couchbase', 'AuroraSnapshotManager', 'O365PublicFolders', 'UDA',
                'O365Teams', 'O365Group', 'O365Exchange', 'O365OneDrive', 'O365Sharepoint', 'Sfdc',
                'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown']

cluster = api('get', 'cluster')
outfileName = os.path.join(outputpath, 'activeSnapshots-%s.csv' % cluster['name'])

if days is not None:
    daysBackUsecs = timeAgo(days, 'days')

f = codecs.open(outfileName, 'w', 'utf-8')
f.write('"Cluster Name","Job Name","Job Type","Protected Object","Active Snapshots","Oldest Snapshot","Newest Snapshot","Policy Name"\n')

etail = ''
if environment is not None and len(environment) > 0:
    etail = '&entityTypes=%s' % ','.join(environment)

if excludeenvironment is not None and len(excludeenvironment) > 0:
    excludeenvironment = [e.lower() for e in excludeenvironment]

### find recoverable objects
policies = api('get', 'protectionPolicies?allUnderHierarchy=true')
jobs = sorted(api('get', 'protectionJobs?allUnderHierarchy=true'), key=lambda job: job['name'].lower())
if localonly is True:
    jobs = [j for j in jobs if 'isActive' not in j or j['isActive'] is not False]

for job in jobs:
    tenantTail = ''
    if 'tenantId' in job:
        tenantTail = '&tenantId=%s' % job['tenantId']
    if excludeenvironment is None or len(excludeenvironment) == 0 or (job['environment'].lower() not in excludeenvironment and job['environment'][1:].lower() not in excludeenvironment):

        startfrom = 0
        ro = api('get', '/searchvms?allUnderHierarchy=true&jobIds=%s&size=%s&from=%s%s%s' % (job['id'], pagesize, startfrom, etail, tenantTail))
        if len(ro) > 0:
            while True:
                if 'vms' in ro:
                    ro['vms'].sort(key=lambda obj: obj['vmDocument']['jobName'])
                    for vm in ro['vms']:
                        doc = vm['vmDocument']
                        jobId = doc['objectId']['jobId']
                        jobName = doc['jobName']
                        objName = doc['objectName']
                        objType = environments[doc['registeredSource']['type']]
                        objSource = doc['registeredSource']['displayName']
                        policyName = [p['name'] for p in policies if p['id'] == job['policyId']]
                        if policyName is not None and len(policyName) > 0:
                            policyName = policyName[0]
                        else:
                            policyName = ''
                        objAlias = ''
                        if 'objectAliases' in doc:
                            objAlias = doc['objectAliases'][0]
                            if objAlias == objName + '.vmx':
                                objAlias = ''
                            if objType == 'VMware':
                                objAlias = ''
                        if objType == 'View':
                            objSource = ''

                        if objAlias != '':
                            objName = '%s/%s' % (objAlias, objName)
                        versions = sorted(doc['versions'], key=lambda s: s['instanceId']['jobStartTimeUsecs'])
                        if days is not None:
                            versions = [v for v in versions if v['instanceId']['jobStartTimeUsecs'] >= daysBackUsecs]
                        versionCount = len(versions)
                        if versionCount > 0:
                            oldestSnapshotDate = usecsToDate(versions[0]['instanceId']['jobStartTimeUsecs'])
                            newsetSnapshotDate = usecsToDate(versions[-1]['instanceId']['jobStartTimeUsecs'])
                        else:
                            oldestSnapshotDate = ''
                            newsetSnapshotDate = ''
                        print("%s (%s) %s: %s" % (jobName, objType, objName, versionCount))
                        f.write('"%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], jobName, objType, objName, versionCount, oldestSnapshotDate, newsetSnapshotDate, policyName))
                if ro['count'] > (pagesize + startfrom):
                    startfrom += pagesize
                    ro = api('get', '/searchvms?allUnderHierarchy=truejobIds=%s&size=%s&from=%s%s%s' % (job['id'], pagesize, startfrom, etail, tenantTail))
                else:
                    break
f.close()
