#!/usr/bin/env python
"""List Recovery Points for python"""

### usage: ./recoveryPoints.py -v mycluster -u admin [-d local]

### import pyhesity wrapper module
from pyhesity import *
import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-o', '--objectname', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
jobname = args.jobname
objectname = args.objectname

### authenticate
apiauth(vip, username, domain)

dateString = datetime.datetime.now().strftime("%c").replace(':', '-').replace(' ', '_')
outfileName = 'RecoverPoints-%s.csv' % dateString
f = open(outfileName, "w")
f.write("jobName,objType,objName,startTime,runURL\n")

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
            runId = version['instanceId']['jobInstanceId']
            startTime = version['instanceId']['jobStartTimeUsecs']
            runURL = "https://%s/protection/job/%s/run/%s/%s/protection" % (vip, jobId, runId, startTime)
            print("\t%s\t%s" % (usecsToDate(startTime), runURL))
            f.write("%s,%s,%s,%s,%s\n" % (jobName, objType, objName, usecsToDate(startTime), runURL))
f.close()
