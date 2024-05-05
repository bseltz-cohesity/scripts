#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-o', '--objectname', type=str, required=True)

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
jobname = args.jobname
objectname = args.objectname

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

jobs = api('get', 'data-protect/protection-groups?names=%s&isActive=true&isDeleted=false&pruneSourceIds=true&pruneExcludedSourceIds=true' % jobname, v=2)
job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
if len(job) == 1:
    job = job[0]
    runs = api('get', 'data-protect/protection-groups/%s/runs?localBackupRunStatus=Running&includeObjectDetails=true' % job['id'], v=2)
    if runs is not None and 'runs' in runs and len(runs['runs']) > 0:
        for run in runs['runs']:
            localTaskId = run['localBackupInfo']['localTaskId']
            object = [o for o in run['objects'] if o['object']['name'].lower() == objectname.lower()]
            if len(object) == 1:
                object = object[0]
                cancelParams = {
                    "action": "Cancel",
                    "cancelParams": [
                        {
                            "runId": run['id'],
                            "localTaskId": localTaskId,
                            "objectIds": [
                                object['object']['id']
                            ]
                        }
                    ]
                }
                print("Canceling run for %s" % objectname)
                cancel = api('post', 'data-protect/protection-groups/%s/runs/actions' % job['id'], cancelParams, v=2)
            else:
                print("%s not running" % objectname)
    else:
        print("Protection group %s is not running" % jobname)
        exit()
else:
    print("Protection group %s not found" % jobname)
    exit()
