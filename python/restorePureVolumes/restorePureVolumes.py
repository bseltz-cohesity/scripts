#!/usr/bin/env python
"""Restore Pure Storage Volumes Using python"""

# usage: ./restorePureVolumes.py -c mycluster -u myusername -a mypure -v myserver_lun1 -v myserver_lun2 -p restore- -s -0410

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--cluster', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-a', '--purename', type=str, required=True)  # name of registered pure array
parser.add_argument('-v', '--volumename', action='append', type=str)  # volume name(s) to recover
parser.add_argument('-l', '--volumelist', type=str)  # file of volumes names to recover
parser.add_argument('-p', '--prefix', type=str, required=True)  # prefix to apply to recovered volumes
parser.add_argument('-s', '--suffix', type=str, required=True)  # suffix to apply to recovered volumes

args = parser.parse_args()

vip = args.cluster
username = args.username
domain = args.domain
purename = args.purename
volumes = args.volumename
volumelist = args.volumelist
prefix = args.prefix
suffix = args.suffix

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

# authenticate to Cohesity
apiauth(vip, username, domain)


# volume search function
def searchvolume(purename, volumename):
    searchresult = api('get', '/searchvms?entityTypes=kPure&vmName=%s' % volumename)
    if len(searchresult) == 0 or not ('vms' in searchresult):
        return None
    else:
        volume = [v for v in searchresult['vms'] if v['vmDocument']['objectName'].lower() == volumename.lower() and v['vmDocument']['registeredSource']['displayName'].lower() == purename.lower()]
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

taskdate = datetime.now().strftime("%h_%d_%Y_%H-%M%p")

# proceed with restores
for volumename in volumes:
    # find volume
    volume = searchvolume(purename, volumename)
    if volume is None:
        print("Volume %s/%s not found!" % (purename, volumename))
        exit(1)
    else:
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
                    'jobInstanceId': volume['versions'][0]['instanceId']['jobInstanceId'],
                    'attemptNum': volume['versions'][0]['instanceId']['attemptNum'],
                    'startTimeUsecs': volume['versions'][0]['instanceId']['jobStartTimeUsecs']
                }
            ],
            'restoreParentSource': volume['registeredSource'],
            'renameRestoredObjectParam': {
                'prefix': prefix,
                'suffix': suffix
            }
        }
        # perform restore
        print("Restoring %s/%s as %s/%s%s%s" % (purename, volumename, purename, prefix, volumename, suffix))
        result = api('post', '/restore', restoreParams)
