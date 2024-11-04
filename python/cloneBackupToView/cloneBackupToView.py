#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime

# command line arguments
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
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='TestAndDev High')  # qos policy
parser.add_argument('-w', '--whitelist', action='append', default=[])  # ip to whitelist
parser.add_argument('-x', '--deleteview', action='store_true')  # delete existing view
parser.add_argument('-j', '--jobname', type=str, default=None)  # name job to clone
parser.add_argument('-o', '--objectname', type=str, default=None)  # name job to clone
parser.add_argument('-y', '--daysback', type=int, default=0)

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
viewName = args.viewname
qosPolicy = args.qospolicy
whitelist = args.whitelist
deleteview = args.deleteview
jobname = args.jobname
objectname = args.objectname
daysback = args.daysback

# netmask2cidr
def netmask2cidr(netmask):
    bin = ''.join(["{0:b}".format(int(o)) for o in netmask.split('.')])
    if '0' in bin:
        cidr = bin.index('0')
    else:
        cidr = 32
    return cidr


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

if daysback > 0:
    daysBackUsecs = timeAgo(daysback, 'days')

if deleteview is not True:

    if jobname is None:
        print('-j, --jobname required!')
        exit(1)

    # get protection job
    job = [job for job in api('get', 'protectionJobs') if job['name'].lower() == jobname.lower()]
    if not job:
        print("Job '%s' not found" % jobname)
        exit(1)
    else:
        job = job[0]
        sdid = job['viewBoxId']

existingview = None
views = api('get', 'views')
if views['count'] > 0:
    existingviews = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if len(existingviews) > 0:
        existingview = existingviews[0]

if existingview is None and deleteview is not True:

    # new view parameters
    newView = {
        "caseInsensitiveNamesEnabled": True,
        "enableNfsViewDiscovery": True,
        "enableSmbAccessBasedEnumeration": False,
        "enableSmbViewDiscovery": True,
        "fileExtensionFilter": {
            "isEnabled": False,
            "mode": "kBlacklist",
            "fileExtensionsList": []
        },
        "protocolAccess": "kNFSOnly",
        "securityMode": "kNativeMode",
        "subnetWhitelist": [],
        "qos": {
            "principalName": qosPolicy
        },
        "name": viewName,
        "viewBoxId": sdid
    }

    if len(whitelist) > 0:

        for ip in whitelist:
            if ',' in ip:
                (thisip, netmask) = ip.split(',')
                netmask = netmask.lstrip()
                cidr = netmask2cidr(netmask)
            else:
                thisip = ip
                netmask = '255.255.255.255'
                cidr = 32

            newView['subnetWhitelist'].append({
                "description": '',
                "nfsAccess": "kReadWrite",
                "smbAccess": "kReadWrite",
                "nfsRootSquash": False,
                "ip": thisip,
                "netmaskIp4": netmask
            })

    print("Creating new view %s..." % viewName)
    result = api('post', 'views', newView)
    sleep(5)
    views = api('get', 'views')
    if views['count'] > 0:
        existingviews = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
        if len(existingviews) > 0:
            view = existingviews[0]

else:
    if deleteview is True:
        if existingview:
            print("Deleting view %s..." % viewName)
            result = api('delete', 'views/%s' % viewName)
        else:
            print("View %s does not exist" % viewName)
        exit(0)
    else:
        if existingview['viewBoxId'] != job['viewBoxId']:
            print('View and job must be in the same storage domain!')
            exit(1)
        print("Using existing view: %s" % viewName)
        view = existingview


successStates = ['kSuccess', 'kWarning']

# get runs
thisObjectFound = False
if daysback > 0:
    runs = [r for r in api('get', 'protectionRuns?jobId=%s&startTimeUsecs=%s' % (job['id'], daysBackUsecs)) if r['backupRun']['snapshotsDeleted'] is False and r['backupRun']['status'] in successStates]
else:
    runs = [r for r in api('get', 'protectionRuns?jobId=%s' % job['id']) if r['backupRun']['snapshotsDeleted'] is False and r['backupRun']['status'] in successStates]
if len(runs) > 0:
    for run in runs:
        runType = run['backupRun']['runType'][1:]
        for sourceInfo in run['backupRun']['sourceBackupStatus']:
            thisObjectName = sourceInfo['source']['name']
            if objectname is None or thisObjectName.lower() == objectname.lower():
                if sourceInfo['status'] in successStates:
                    thisObjectFound = True
                    if 'viewName' in sourceInfo['currentSnapshotInfo']:
                        sourceView = sourceInfo['currentSnapshotInfo']['viewName']
                    elif 'rootPath' in sourceInfo['currentSnapshotInfo']:
                        sourceView = sourceInfo['currentSnapshotInfo']['rootPath'].split('/')[2]
                    else:
                        thisRun = api('get', '/backupjobruns?id=%s&exactMatchStartTimeUsecs=%s' % (run['jobId'], run['backupRun']['stats']['startTimeUsecs']))
                        if 'viewName' in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks'][0]:
                            sourceView = thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks'][0]['viewName']
                        elif 'viewName' in thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks'][0]['currentSnapshotInfo']:
                            sourceView = thisRun[0]['backupJobRuns']['protectionRuns'][0]['backupRun']['latestFinishedTasks'][0]['currentSnapshotInfo']['viewName']
                        else:
                            print('no view path found for %s protection run' % job['environment'])
                            continue
                    if 'relativeSnapshotDirectory' in sourceInfo['currentSnapshotInfo']:
                        sourcePath = sourceInfo['currentSnapshotInfo']['relativeSnapshotDirectory']
                    else:
                        sourcePath = ''

                    starttimeString = datetime.strptime(usecsToDate(run['backupRun']['stats']['startTimeUsecs']), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d_%H-%M-%S')
                    destinationPath = "%s-%s-%s" % (thisObjectName, starttimeString, runType)
                    CloneDirectoryParams = {
                        'destinationDirectoryName': destinationPath,
                        'destinationParentDirectoryPath': '/%s' % view['name'],
                        'sourceDirectoryPath': '/%s/%s' % (sourceView, sourcePath),
                    }
                    folderPath = "%s:/%s/%s" % (vip, viewName, destinationPath)
                    print("Cloning %s backup files to %s" % (thisObjectName, folderPath))
                    result = api('post', 'views/cloneDirectory', CloneDirectoryParams)
    if thisObjectFound is False:
        print('No runs found containing %s' % objectname)
else:
    print('No runs found for job %s' % jobname)
    exit(1)
