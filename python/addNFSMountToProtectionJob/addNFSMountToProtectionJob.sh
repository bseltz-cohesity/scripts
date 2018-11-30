#!/usr/bin/env python
"""Add NFS Mount to Protection Job for python"""

### usage: ./addNFSMountToProtectionJob.sh -v mycluster -u username -j 'My Job Name' -m 192.168.1.4:/var/nfs2 [-d mydomain]

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v','--vip', type=str, required=True)
parser.add_argument('-u','--username', type=str, required=True)
parser.add_argument('-d','--domain',type=str,default='local')
parser.add_argument('-j','--jobName', type=str, required=True)
parser.add_argument('-m','--mountPath', type=str, required=True )

args = parser.parse_args()
    
vip = args.vip
username = args.username
domain = args.domain
jobName = args.jobName
mountPath = args.mountPath

### authenticate
apiauth(vip, username, domain)

### find protectionJob
job = [ job for job in api('get','protectionJobs') if job['name'].lower() == jobName.lower() ][0]
if not job:
    print "Job '%s' not found" % jobName
    exit()

### new NAS MountPoint Definition
newNASMount = {
    'entity': {
        'type': 11,
        'genericNasEntity': {
            'protocol': 1,
            'type': 1,
            'path': mountPath
        }
    },
    'entityInfo': {
        'endpoint': mountPath,
        'type': 11
    }
}

### check for existing mountPoint
mountPoints = api('get','/backupsources?envTypes=11')['entityHierarchy']['children'][0]['children']
mountPoint = [mountPoint for mountPoint in mountPoints if mountPoint['entity']['genericNasEntity']['path'].lower() == mountPath.lower() ]

### register new NAS MountPoint
if (len(mountPoint) == 0):
    result = api('post','/backupsources', newNASMount)
    id = result['id']
else:
    id = mountPoint[0]['entity']['id']

### add new mountPath to ProtectionJob
if(id not in job['sourceIds']):
    job['sourceIds'].append(id)
    result = api('put','protectionJobs/'+str(job['id']),job)
    if('priority' in result):
        print '%s successfully added to %s' % (mountPath, jobName)
else:
    print '%s already protected by %s' % (mountPath, jobName)



