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
parser.add_argument('-n', '--viewname', action='append', type=str)
parser.add_argument('-l', '--viewlist', type=str, default=None)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-di', '--disableindexing', action='store_true')
parser.add_argument('-suffix', '--drsuffix', type=str, default='')
parser.add_argument('-prefix', '--drprefix', type=str, default='')
parser.add_argument('-ct', '--clienttype', type=str, choices=['Generic', 'SBT'], default='Generic')
parser.add_argument('-cv', '--catalogview', type=str, default='')

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
viewnames = args.viewname
viewlist = args.viewlist
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
pause = args.pause
disableindexing = args.disableindexing
drsuffix = args.drsuffix
drprefix = args.drprefix
clienttype = args.clienttype
catalogview = args.catalogview

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


# gather list function
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


# get list of views to protect
viewstoadd = gatherList(viewnames, viewlist, name='views', required=True)

cluster = api('get', 'cluster')
if cluster['clusterSoftwareVersion'] < '6.6' and len(viewstoadd) > 1:
    print('Cohesity versions prior to 6.6 can only protect one view per job')
    exit(1)

views = api('get', 'file-services/views', v=2)
if catalogview != '':
    thisView = [v for v in views['views'] if v['name'].lower() == catalogview.lower()]
    if thisView is None or len(thisView) == 0:
        print('Catalog view %s not found' % catalogview)
        exit(1)
    else:
        catalogview = thisView[0]['name']


# get the protection job
jobs = api('get', 'data-protect/protection-groups?environments=kView', v=2)
job = None
if 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    job = [j for j in (api('get', 'data-protect/protection-groups?environments=kView', v=2))['protectionGroups'] if j['name'].lower() == jobname.lower()]
if job is None or len(job) == 0:
    newJob = True
    if cluster['clusterSoftwareVersion'] < '6.6' and len(viewstoadd) > 1:
        print('Cohesity versions prior to 6.6 can only protect one view per job')
        exit(1)

    # new job
    if pause:
        isPaused = True
    else:
        isPaused = False

    # get policy
    if policyname is None:
        print('Policy name required')
        exit(1)
    else:
        policy = [p for p in (api('get', 'data-protect/policies', v=2))['policies'] if p['name'].lower() == policyname.lower()]
        if policy is None or len(policy) == 0:
            print('Policy %s not found' % policyname)
            exit(1)
        else:
            policy = policy[0]

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

    if disableindexing is True:
        enableindexing = False
    else:
        enableindexing = True

    job = {
        "name": jobname,
        "environment": "kView",
        "isPaused": isPaused,
        "policyId": policy['id'],
        "priority": "kMedium",
        "storageDomainId": 0,
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
                "backupRunType": "kFull"
            },
            {
                "backupRunType": "kIncremental"
            }
        ],
        "viewParams": {
            "indexingPolicy": {
                "enableIndexing": enableindexing,
                "includePaths": [
                    "/"
                ],
                "excludePaths": []
            },
            "objects": []
        }
    }
    if 'remoteTargetPolicy' in policy and 'replicationTargets' in policy['remoteTargetPolicy']:
        if cluster['clusterSoftwareVersion'] < '6.6':
            job['viewParams']['replicationParams'] = {}
        else:
            job['viewParams']['replicationParams'] = {
                "viewNameConfigList": []
            }
else:
    # existing job
    newJob = False
    job = job[0]
    if job['environment'] != 'kView':
        print('Job %s exists but is not a view protection job' % jobname)
        exit(1)
    if cluster['clusterSoftwareVersion'] < '6.6':
        print('Cohesity versions prior to 6.6 can only protect one view per job')
        exit(1)

for thisViewName in viewstoadd:

    thisView = [v for v in views['views'] if v['name'].lower() == thisViewName.lower()]
    if thisView is None or len(thisView) == 0:
        print('View %s not found' % thisViewName)
        exit(1)
    else:
        thisView = thisView[0]
        if job['storageDomainId'] == 0:
            job['storageDomainId'] = thisView['storageDomainId']
        elif job['storageDomainId'] != thisView['storageDomainId']:
            print('View %s is in a different storage domain than the protection job %s. Skipping...' % (thisViewName, job['name']))
            continue
        job['viewParams']['objects'] = [o for o in job['viewParams']['objects'] if o['id'] != thisView['viewId']]
        job['viewParams']['objects'].append({"id": thisView['viewId']})
        if 'replicationParams' in job['viewParams']:
            drViewName = thisViewName
            useSameViewName = True
            if drsuffix != '':
                drViewName = '%s-%s' % (drViewName, drsuffix)
                useSameViewName = False
            if drprefix != '':
                drViewName = '%s-%s' % (drprefix, drViewName)
                useSameViewName = False
            if cluster['clusterSoftwareVersion'] < '6.6':
                job['viewParams']['replicationParams'] = {
                    "createView": True,
                    "viewName": drViewName
                }
            else:
                job['viewParams']['replicationParams']['viewNameConfigList'] = [v for v in job['viewParams']['replicationParams']['viewNameConfigList'] if v['sourceViewId'] != thisView['viewId']]
                job['viewParams']['replicationParams']['viewNameConfigList'].append({
                    "sourceViewId": thisView['viewId'],
                    "useSameViewName": useSameViewName,
                    "viewName": drViewName
                })
        if 'isExternallyTriggeredBackupTarget' in thisView and thisView['isExternallyTriggeredBackupTarget'] is True:
            job['viewParams']['externallyTriggeredJobParams'] = {
                "clientType": clienttype,
                "sbtParams": {
                    "catalogView": catalogview
                }
            }

# save job
if newJob is True:
    print('Creating protection job "%s"...' % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print('Updating protection job "%s"...' % jobname)
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
