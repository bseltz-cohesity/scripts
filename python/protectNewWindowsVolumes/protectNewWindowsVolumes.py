#!/usr/bin/env python
"""Add new volumes to file-based windows protection job"""

### usage: ./protectLinux.py -v mycluster \
#                            -u myuser \
#                            -d mydomain.net \
#                            -j 'My Backup Job' \
#                            -e 'E:\' \
#                            -e 'F:\' \
#                            -x excludes.txt

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludefile', type=str)

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
jobname = args.jobname          # name of protection job to add server to
excludes = args.exclude         # exclude path
excludefile = args.excludefile  # file with exclude paths

# read exclude file
if excludes is None:
    excludes = []
if excludefile is not None:
    f = open(excludefile, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# authenticate to Cohesity
apiauth(vip, username, domain)

# get job info
job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
if not job:
    print("Job '%s' not found" % jobname)
    exit(1)

job = job[0]

# get registered physical servers
physicalServersRoot = api('get', 'protectionSources/rootNodes?allUnderHierarchy=false&environments=kPhysicalFiles&environments=kPhysical&environments=kPhysical')
physicalServersRootId = physicalServersRoot[0]['protectionSource']['id']
sources = api('get', 'protectionSources?allUnderHierarchy=false&id=%s&includeEntityPermissionInfo=true' % physicalServersRootId)[0]['nodes']

madeChanges = False

for param in job['sourceSpecialParameters']:
    sourceId = param['sourceId']
    source = [s for s in sources if s['protectionSource']['id'] == sourceId]
    if len(source) == 0:
        print("no source found with id %s" % sourceId)
    else:
        source = source[0]
        sourceVolumes = source['protectionSource']['physicalProtectionSource']['volumes']
        for volume in sourceVolumes:
            if 'mountPoints' in volume:
                for mountPoint in volume['mountPoints']:
                    mountPath = '/' + mountPoint.replace('\\', '/').replace(':', '')
                    alreadyProtected = False
                    for filePath in param['physicalSpecialParameters']['filePaths']:
                        if 'backupFilePath' in filePath:
                            if filePath['backupFilePath'].lower().startswith(mountPath.lower()):
                                alreadyProtected = True
                    if alreadyProtected is False and mountPoint not in excludes:
                        print("protecting %s on %s" % (mountPoint, source['protectionSource']['name']))
                        param['physicalSpecialParameters']['filePaths'].append({
                            "backupFilePath": mountPath,
                            "skipNestedVolumes": True
                        })
                        madeChanges = True

if madeChanges is True:
    updateJob = api('put', 'protectionJobs/%s' % job['id'], job)
else:
    print("Nothing new to protect")
