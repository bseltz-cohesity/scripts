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
#                            -e /var/log(\
#                            -e /home/oracle \
#                            -e *.dbf \
#                            -f excludes.txt

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-j', '--jobname', type=str, default=None)
parser.add_argument('-o', '--olderthan', type=int, default=0)
parser.add_argument('-x', '--delete', action='store_true')

args = parser.parse_args()

vip = args.vip                  # cluster name/ip
username = args.username        # username to connect to cluster
domain = args.domain            # domain of username (e.g. local, or AD domain)
servernames = args.servername   # name of server to protect
serverlist = args.serverlist    # file with server names
jobname = args.jobname          # name of protection job to add server to
olderthan = args.olderthan
commit = args.delete

# read server file
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

# authenticate to Cohesity
apiauth(vip, username, domain)

# get job info
if jobname is not None:
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
    if not job:
        print("Job '%s' not found" % jobname)
        exit(1)
    job = job[0]

# logging
runDate = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
logfile = open("expungeVMLog-%s.txt" % runDate, 'w')


def log(text):
    print(text)
    logfile.write("%s\n" % text)


log("- Started at %s -------\n" % runDate)

olderThanUsecs = timeAgo(olderthan, 'days')

for serverName in servernames:
    search = api('get', '/searchvms?vmName=%s' % serverName)
    objects = [v for v in search['vms'] if v['vmDocument']['objectName'].lower() == serverName.lower()]
    for object in objects:
        sourceId = object['vmDocument']['objectId']['entity']['id']
        protectionGroupName = object['vmDocument']['jobName']
        protectionGroupId = object['vmDocument']['objectId']['jobId']
        if (jobname is None) or (jobname.lower() == protectionGroupName.lower()):
            for version in object['vmDocument']['versions']:
                runStartTimeUsecs = version['instanceId']['jobStartTimeUsecs']
                localBackup = [b for b in version['replicaInfo']['replicaVec'] if b['target']['type'] == 1]

                if runStartTimeUsecs < olderThanUsecs and len(localBackup) > 0:

                    run = api('get', '/backupjobruns?id=%s&ExactMatchStartTimeUsecs=%s' % (protectionGroupId, runStartTimeUsecs))
                    deleteObjectParams = {
                        "jobRuns": [
                            {
                                "copyRunTargets": [
                                    {
                                        "daysToKeep": 0,
                                        "type": "kLocal"
                                    }
                                ],
                                "jobUid": {
                                    "clusterId": object['vmDocument']['objectId']['jobUid']['clusterId'],
                                    "clusterIncarnationId": object['vmDocument']['objectId']['jobUid']['clusterIncarnationId'],
                                    "id": object['vmDocument']['objectId']['jobUid']['objectId']
                                },
                                "runStartTimeUsecs": runStartTimeUsecs,
                                "sourceIds": [
                                    sourceId
                                ]
                            }
                        ]
                    }
                    if commit is True:
                        log("Deleting %s from %s (%s)" % (serverName, protectionGroupName, usecsToDate(runStartTimeUsecs)))
                        deletion = api('put', 'protectionRuns', deleteObjectParams)
                    else:
                        log("Would delete %s from %s (%s)" % (serverName, protectionGroupName, usecsToDate(runStartTimeUsecs)))

logfile.close()
print('\nLog written to expungeVMLog-%s.txt\n' % runDate)
