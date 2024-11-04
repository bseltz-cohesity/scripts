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
#                            -f excludes.txt

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-i', '--instancename', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
servernames = args.servername         # name of server to protect
serverlist = args.serverlist          # file with server names
instancename = args.instancename      # name of SQL instance to protect
jobname = args.jobname                # name of protection job to add server to
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job

# read server file
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if len(servernames) == 0:
    print('no servers specified')
    exit()

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
job = [job for job in jobs if job['name'].lower() == jobname.lower()]

if not job or len(job) < 1:
    newJob = True
    print("Creating new Job '%s'" % jobname)

    # find protectionPolicy
    if policyname is None:
        print('Policy name required for new job')
        exit(1)
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']

    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
    if len(sd) < 1:
        print("Storage domain %s not found!" % storagedomain)
        exit(1)
    sdid = sd[0]['id']

    # parse starttime
    try:
        (hour, minute) = starttime.split(':')
        hour = int(hour)
        minute = int(minute)
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            print('starttime is invalid!')
            exit(1)
    except Exception:
        print('starttime is invalid!')
        exit(1)

    job = {
        "name": jobname,
        "environment": "kSQL",
        "isPaused": False,
        "policyId": policyid,
        "priority": "kMedium",
        "storageDomainId": sdid,
        "description": "",
        "startTime": {
            "hour": hour,
            "minute": minute,
            "timeZone": timezone
        },
        "abortInBlackouts": False,
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "sla": [
            {
                "backupRunType": "kFull",
                "slaMinutes": fullsla
            },
            {
                "backupRunType": "kIncremental",
                "slaMinutes": incrementalsla
            }
        ],
        "qosPolicy": "kBackupHDD",
        "mssqlParams": {
            "protectionType": "kFile",
            "fileProtectionTypeParams": {
                "performSourceSideDeduplication": False,
                "fullBackupsCopyOnly": False,
                "userDbBackupPreferenceType": "kBackupAllDatabases",
                "backupSystemDbs": True,
                "useAagPreferencesFromServer": True,
                "objects": []
            }
        }
    }

else:
    job = job[0]
    if job['environment'] != 'kSQL' or job['mssqlParams']['protectionType'] != 'kFile':
        print("Job '%s' is not a SQL file-based protection job" % jobname)
        exit(1)

# get registered sql servers
sources = api('get', 'protectionSources?environments=kSQL')

for servername in servernames:
    # find server
    server  = [s for s in sources[0]['nodes'] if s['protectionSource']['name'].lower() == servername.lower()]
    if not server or len(server) == 0:
        print("******** %s is not a registered SQL server ********" % servername)
    else:
        server = server[0]
        if instancename is None:
            # avoid duplicates
            job['mssqlParams']['fileProtectionTypeParams']['objects'] = [o for o in job['mssqlParams']['fileProtectionTypeParams']['objects'] if o['id'] != server['protectionSource']['id']]
            # add server to job
            job['mssqlParams']['fileProtectionTypeParams']['objects'].append({'id': server['protectionSource']['id']})
            # remove instances since entire server is protected
            for appnode in server['applicationNodes']:
                job['mssqlParams']['fileProtectionTypeParams']['objects'] = [o for o in job['mssqlParams']['fileProtectionTypeParams']['objects'] if o['id'] != appnode['protectionSource']['id']]
        else:
            instance = [i for i in server['applicationNodes'] if i['protectionSource']['name'].lower() == instancename.lower()]
            if instance is None or len(instance) == 0:
                print('******** instance %s not found on server %s ********' % (instancename, servername)) 
            else:
                instance = instance[0]
                # avoid duplicates
                job['mssqlParams']['fileProtectionTypeParams']['objects'] = [o for o in job['mssqlParams']['fileProtectionTypeParams']['objects'] if o['id'] != instance['protectionSource']['id']]
                job['mssqlParams']['fileProtectionTypeParams']['objects'].append({'id': instance['protectionSource']['id']})

if len(job['mssqlParams']['fileProtectionTypeParams']['objects']) == 0:
    print('no job created')
    exit(1)

# update job
if newJob is True:
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print("Updating Job '%s'" % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
