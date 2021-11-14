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
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-o', '--objectname', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
useApiKey = args.useApiKey
jobname = args.jobname
objectname = args.objectname

### authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')
now = datetime.now()
nowstring = now.strftime("%Y-%m-%d")
outfileName = '%s/RecoverPoints-%s-%s.csv' % (folder, cluster['name'], nowstring)

f = codecs.open(outfileName, 'w', 'utf-8')
f.write("Job Name,Object Type,Object Name,Start Time,Local Expiry,Archive Target,Archive Expiry\n")

jobtail = ''
if jobname is not None:
    jobs = api('get', 'protectionJobs')
    job = [j for j in jobs if j['name'].lower() == jobname.lower()]
    if len(job) == 0:
        print("Job %s not found" % jobname)
        exit(1)
    jobtail = '?jobIds=%s' % job[0]['id']

objtail = ''
if objectname is not None:
    if jobtail != '':
        objtail = '&vmName=%s' % objectname
    else:
        objtail = '?vmName=%s' % objectname

### find recoverable objects
ro = api('get', '/searchvms%s%s' % (jobtail, objtail))

environments = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View',
                'RemoteAdapter', 'Physical', 'Pure', 'Azure', 'Netapp',
                'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS',
                'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
                'O365', 'O365Outlook', 'HyperFlex', 'GCPNative',
                'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown',
                'Unknown', 'Unknown', 'Unknown']

if len(ro) > 0:

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
        print("%s(%s) %s" % (jobName, objType, objName))
        for version in doc['versions']:
            archiveTarget = '-'
            archive = 0
            local = 0
            runId = version['instanceId']['jobInstanceId']
            startTime = usecsToDate(version['instanceId']['jobStartTimeUsecs'])
            print("\t%s" % startTime)
            for replica in version['replicaInfo']['replicaVec']:
                if replica['target']['type'] == 1:
                    if replica['expiryTimeUsecs'] > 0:
                        local = replica['expiryTimeUsecs']
                if replica['target']['type'] == 3:
                    if replica['expiryTimeUsecs'] > archive:
                        archive = replica['expiryTimeUsecs']
                        archiveTarget = replica['target']['archivalTarget']['name']
            if local > 0:
                localExpiry = usecsToDate(local)
            else:
                localExpiry = '-'
            if archive > 0:
                archiveExpiry = usecsToDate(archive)
            else:
                archiveExpiry = '-'

            f.write("%s,%s,%s,%s,%s,%s,%s\n" % (jobName, objType, objName, startTime, localExpiry, archiveTarget, archiveExpiry))
f.close()
