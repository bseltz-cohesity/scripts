#!/usr/bin/env python
"""Clone Oracle Backups to a View Using python"""

# import pyhesity wrapper module
from pyhesity import *
from time import sleep
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-n', '--viewname', type=str, required=True)  # name view to create
parser.add_argument('-q', '--qospolicy', type=str, choices=['Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low'], default='TestAndDev High')  # qos policy
parser.add_argument('-w', '--whitelist', action='append', default=[])  # ip to whitelist
parser.add_argument('-x', '--deleteview', action='store_true')  # delete existing view
parser.add_argument('-j', '--jobname', type=str, default=None)  # name job to clone
parser.add_argument('-o', '--objectname', type=str, default=None)  # name job to clone

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
viewName = args.viewname
qosPolicy = args.qospolicy
whitelist = args.whitelist
deleteview = args.deleteview
jobname = args.jobname
objectname = args.objectname


# netmask2cidr
def netmask2cidr(netmask):
    bin = ''.join(["{0:b}".format(int(o)) for o in netmask.split('.')])
    if '0' in bin:
        cidr = bin.index('0')
    else:
        cidr = 32
    return cidr


# authenticate
apiauth(vip, username, domain)

if deleteview is not True:

    if jobname is None:
        print('-j, --jobname required!')
        exit(1)

    if objectname is None:
        print('-o, --objectname reqiured!')
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
views = api('get', 'views?includeInternalViews=true')
if views['count'] > 0:
    existingviews = [v for v in views['views'] if v['name'].lower() == viewName.lower()]
    if len(existingviews) > 0:
        existingview = existingviews[0]
        viewName = existingview['name']

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
    newview = None
    print("Waiting for new view to come online...")
    while newview is None:
        sleep(5)
        newview = api('get', 'views/%s' % viewName)
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
runs = [r for r in api('get', 'protectionRuns?jobId=%s' % job['id']) if r['backupRun']['snapshotsDeleted'] is False]
if len(runs) > 0:
    for run in runs:
        runType = run['backupRun']['runType'][1:]
        for sourceInfo in run['backupRun']['sourceBackupStatus']:
            thisObjectName = sourceInfo['source']['name']
            if objectname is None or thisObjectName.lower() == objectname.lower():
                thisObjectFound = True
                sourceView = [v for v in views['views'] if '_%s_' % run['backupRun']['jobRunId'] in v['name'] and '_%s_' % job['id'] in v['name']]
                if sourceView is not None and len(sourceView) > 0:
                    sourceView = sourceView[0]
                    starttimeString = datetime.strptime(usecsToDate(run['backupRun']['stats']['startTimeUsecs']), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d_%H-%M-%S')
                    destinationPath = "%s-%s-%s" % (thisObjectName, starttimeString, runType)
                    CloneDirectoryParams = {
                        'destinationDirectoryName': destinationPath,
                        'destinationParentDirectoryPath': '/%s' % viewName,
                        'sourceDirectoryPath': '/%s/' % sourceView['name'],
                    }
                    folderPath = "%s:/%s/%s" % (vip, viewName, destinationPath)
                    print("Cloning %s backup files to %s" % (thisObjectName, folderPath))
                    result = api('post', 'views/cloneDirectory', CloneDirectoryParams)
    if thisObjectFound is False:
        print('No runs found containing %s' % objectname)
else:
    print('No runs found for job %s' % jobname)
    exit(1)
