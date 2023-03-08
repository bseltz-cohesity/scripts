#!/usr/bin/env python
"""Restore Pure Storage Volumes Using python"""

# usage: ./restorePureVolumes.py -c mycluster -u myusername -a mypure -v myserver_lun1 -v myserver_lun2 -p restore- -s -0410

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)  # name of registered pure array
parser.add_argument('-a', '--purename', type=str, required=True)  # name of registered pure array
parser.add_argument('-n', '--volumename', action='append', type=str)  # volume name(s) to recover
parser.add_argument('-l', '--volumelist', type=str)  # file of volumes names to recover
parser.add_argument('-p', '--prefix', type=str, default=None)  # prefix to apply to recovered volumes
parser.add_argument('-s', '--suffix', type=str, default=None)  # suffix to apply to recovered volumes
parser.add_argument('-x', '--showversions', action='store_true')      # show available snapshots
parser.add_argument('-r', '--runid', type=int, default=None)          # choose specific job run id

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobname = args.jobname
purename = args.purename
volumes = args.volumename
volumelist = args.volumelist
prefix = args.prefix
suffix = args.suffix
showversions = args.showversions
runid = args.runid

if suffix is None and prefix is None:
    print('--prefix or --suffix required!')
    exit()

if suffix and suffix[0] != '-':
    suffix = "-%s" % suffix

# gather volume list
if volumes is None:
    volumes = []
if volumelist is not None:
    f = open(volumelist, 'r')
    volumes += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
if len(volumes) == 0:
    print("No volumes specified")
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)


# volume search function
def searchvolume(purename, volumename):
    searchresult = api('get', '/searchvms?entityTypes=kPure&vmName=%s' % volumename)
    if len(searchresult) == 0 or not ('vms' in searchresult):
        return None
    else:
        volume = [v for v in searchresult['vms'] if v['vmDocument']['objectName'].lower() == volumename.lower() and v['vmDocument']['registeredSource']['displayName'].lower() == purename.lower() and v['vmDocument']['jobName'].lower() == jobname.lower()]
        if not volume:
            return None
        else:
            return volume[0]['vmDocument']


# validate all volumes exist before starting any restores
for volumename in volumes:
    volume = searchvolume(purename, volumename)
    if volume is None:
        print("Volume %s/%s not found!" % (purename, volumename))
        exit(1)
    else:
        if showversions:
            for version in volume['versions']:
                print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))
            exit()
        if runid is not None:
            version = [v for v in volume['versions'] if v['instanceId']['jobInstanceId'] == runid]
            if version is None or len(version) == 0:
                print('volume %s is not present in runId %s' % (volumename, runid))
                exit(1)

taskdate = datetime.now().strftime("%h_%d_%Y_%H-%M%p")

# proceed with restores
for volumename in volumes:
    # find volume
    volume = searchvolume(purename, volumename)
    if volume is None:
        print("Volume %s/%s not found!" % (purename, volumename))
        exit(1)
    else:
        if runid is not None:
            version = [v for v in volume['versions'] if v['instanceId']['jobInstanceId'] == runid]
            if version is None or len(version) == 0:
                print('volume %s is not present in runId %s' % (volumename, runid))
                exit(1)
            version = version[0]
        else:
            version = volume['versions'][0]
        # define restore params
        taskname = "Recover-pure_%s-%s" % (taskdate, volumename)
        restoreParams = {
            'action': 8,
            'name': taskname,
            'objects': [
                {
                    'jobId': volume['objectId']['jobId'],
                    'jobUid': volume['objectId']['jobUid'],
                    'entity': volume['objectId']['entity'],
                    'jobInstanceId': version['instanceId']['jobInstanceId'],
                    'attemptNum': version['instanceId']['attemptNum'],
                    'startTimeUsecs': version['instanceId']['jobStartTimeUsecs']
                }
            ],
            'restoreParentSource': volume['registeredSource'],
            'renameRestoredObjectParam': {}
        }
        if prefix is not None:
            restoreParams['renameRestoredObjectParam']['prefix'] = prefix
        if suffix is not None:
            restoreParams['renameRestoredObjectParam']['suffix'] = suffix
        # perform restore
        print("Restoring %s/%s as %s/%s%s%s" % (purename, volumename, purename, prefix, volumename, suffix))
        result = api('post', '/restore', restoreParams)
