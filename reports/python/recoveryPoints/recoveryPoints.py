#!/usr/bin/env python
"""List Recovery Points for python"""

### usage: ./recoveryPoints.py -v mycluster -u admin [-d local]

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-e', '--environment', type=str, default=None)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-s', '--pagesize', type=int, default=1000)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
environment = args.environment
folder = args.outfolder
useApiKey = args.useApiKey
pagesize = args.pagesize

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')
now = datetime.now()
nowstring = now.strftime("%Y-%m-%d")
outfileName = '%s/RecoverPoints-%s-%s.csv' % (folder, cluster['name'], nowstring)

f = codecs.open(outfileName, 'w', 'utf-8')
f.write("Job Name,Object Type,Object Name,Start Time,Local Expiry,Archive Target,Archive Expiry\n")

environments = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer', 'Physical',
                'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade',
                'AWSNative', 'VCD', 'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative',
                'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Unknown', 'Kubernetes',
                'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB', 'HBase',
                'Hive', 'Hdfs', 'Couchbase', 'AuroraSnapshotManager', 'O365PublicFolders', 'UDA',
                'O365Teams', 'O365Group', 'O365Exchange', 'O365OneDrive', 'O365Sharepoint', 'Sfdc',
                'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown']

jobs = api('get', 'protectionJobs')
if environment is not None:
    jobs = [j for j in jobs if j['environment'].lower() == environment.lower() or j['environment'].lower()[1:] == environment.lower()]

for job in jobs:

    ### find recoverable objects
    startfrom = 0
    ro = api('get', '/searchvms?jobIds=%s&size=%s&from=%s' % (job['id'], pagesize, startfrom))

    if len(ro) > 0:
        while True:
            ro['vms'].sort(key=lambda obj: obj['vmDocument']['jobName'])
            for vm in ro['vms']:
                doc = vm['vmDocument']
                jobId = doc['objectId']['jobId']
                jobName = doc['jobName']
                objName = doc['objectName']
                objType = environments[doc['registeredSource']['type']]
                objSource = doc['registeredSource']['displayName']
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
                    objName = objName + " on " + objAlias
                print("%s (%s) %s" % (jobName, objType, objName))
                for version in doc['versions']:
                    runId = version['instanceId']['jobInstanceId']
                    startTime = usecsToDate(version['instanceId']['jobStartTimeUsecs'])
                    print("\t%s" % startTime)
                    for replica in version['replicaInfo']['replicaVec']:
                        localExpiry = '-'
                        archiveTarget = '-'
                        archive = 0
                        local = 0
                        if replica['target']['type'] == 1:
                            if 'expiryTimeUsecs' in replica and replica['expiryTimeUsecs'] > 0:
                                local = replica['expiryTimeUsecs']
                                localExpiry = usecsToDate(local)
                                archiveExpiry = '-'
                        if replica['target']['type'] == 3:
                            if 'expiryTimeUsecs' in replica and replica['expiryTimeUsecs'] > archive:
                                archive = replica['expiryTimeUsecs']
                                archiveTarget = replica['target']['archivalTarget']['name']
                                localExpiry = '-'
                                archiveExpiry = usecsToDate(archive)
                        f.write("%s,%s,%s,%s,%s,%s,%s\n" % (jobName, objType, objName, startTime, localExpiry, archiveTarget, archiveExpiry))
            if ro['count'] > (pagesize + startfrom):
                startfrom += pagesize
                ro = api('get', '/searchvms?jobIds=%s&size=%s&from=%s' % (job['id'], pagesize, startfrom))
            else:
                break
f.close()
print('\nOutput saved to %s\n' % outfileName)
