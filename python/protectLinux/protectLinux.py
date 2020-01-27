#!/usr/bin/env python
"""Add Physical Linux Servers to File-based Protection Job Using Python"""

### usage: ./protectLinux.py -v mycluster \
#                            -u myuser \
#                            -d mydomain.net \
#                            -j 'My Backup Job' \
#                            -s myserver1.mydomain.net \
#                            -s myserver2.mydomain.net \
#                            -l serverlist.txt \
#                            -i /var \
#                            -i /home \
#                            -e /var/log \
#                            -e /home/oracle \
#                            -e *.dbf \
#                            -f excludes.txt

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-i', '--include', action='append', type=str)
parser.add_argument('-n', '--includefile', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludefile', type=str)
parser.add_argument('-m', '--skipnestedmountpoints', action='store_true')

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
servernames = args.servername   # name of server to protect
serverlist = args.serverlist    # file with server names
jobname = args.jobname          # name of protection job to add server to
includes = args.include         # include path
includefile = args.includefile  # file with include paths
excludes = args.exclude         # exclude path
excludefile = args.excludefile  # file with exclude paths
skipmountpoints = args.skipnestedmountpoints  # skip nested mount points

# read server file
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

# read include file
if includes is None:
    includes = []
if includefile is not None:
    f = open(includefile, 'r')
    includes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()
if len(includes) == 0:
    includes += '/'

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
physicalServers = api('get', 'protectionSources?allUnderHierarchy=false&id=%s&includeEntityPermissionInfo=true' % physicalServersRootId)[0]['nodes']

if len(servernames) == 0:
    print('no servers specified')
    exit()

for servername in servernames:
    # find server
    physicalServer = [s for s in physicalServers if s['protectionSource']['name'].lower() == servername.lower() and s['protectionSource']['physicalProtectionSource']['hostType'] == 'kLinux']
    if not physicalServer:
        print ("******** %s is not a registered Linux server ********" % servername)
    else:
        physicalServer = physicalServer[0]
        # get sourceSpecialParameters
        if physicalServer['protectionSource']['id'] in job['sourceIds']:
            print('updating %s in job %s...' % (servername, jobname))
            sourceParameters = []
            for sp in job['sourceSpecialParameters']:
                if sp['sourceId'] != physicalServer['protectionSource']['id']:
                    sourceParameters.append(sp)
        else:
            print('  adding %s to job %s...' % (servername, jobname))
            job['sourceIds'].append(physicalServer['protectionSource']['id'])
            sourceParameters = job['sourceSpecialParameters']

        # create new parameter for this server
        newParameter = {
            "physicalSpecialParameters": {
                "filePaths": []
            },
            "sourceId": physicalServer['protectionSource']['id']
        }

        # add includes to parameter
        for include in includes:
            filePath = {
                "backupFilePath": include,
                "excludedFilePaths": [],
                "skipNestedVolumes": skipmountpoints
            }
            newParameter['physicalSpecialParameters']['filePaths'].append(filePath)

        # add excludes to parameter
        for exclude in excludes:
            thisParent = ''
            for include in includes:
                if include in exclude and '/' in exclude:
                    if len(include) > len(thisParent):
                        thisParent = include
            for filePath in newParameter['physicalSpecialParameters']['filePaths']:
                if thisParent == '' or filePath['backupFilePath'] == thisParent:
                    filePath['excludedFilePaths'].append(exclude)

        # include new parameter
        sourceParameters.append(newParameter)
        job['sourceSpecialParameters'] = sourceParameters

# update job
result = api('put', 'protectionJobs/%s' % job['id'], job)
