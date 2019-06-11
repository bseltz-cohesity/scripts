#!/usr/bin/env python
"""Download files from Cohesity backups using Python"""

# usage: ./downloadFile.py -v mycluster -u myusername -d mydomain.net -o myserver -f 'mypath/myfile' -p /Users/myusername/Downloads

from pyhesity import *
from urllib import quote_plus
import sys
import os

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # the Cohesity cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)  # the Cohesity username to use
parser.add_argument('-d', '--domain', type=str, default='local')  # the Cohesity domain to use
parser.add_argument('-o', '--objectname', type=str, required=True)  # the protected object to search
parser.add_argument('-f', '--filesearch', type=str, required=True)  # partial filename to search for
parser.add_argument('-p', '--destinationpath', type=str, required=True)  # local path to download file to

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
objectname = args.objectname
filesearch = args.filesearch
destinationpath = args.destinationpath

# authenticate
apiauth(vip, username, domain)

# identify python version
if sys.version_info[0] < 3:
    pyversion = 2
else:
    pyversion = 3

# find entity
entities = api('get', '/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&environmentTypes=kView&isProtected=true&physicalEntityTypes=kHost&viewEntityTypes=kView&vmwareEntityTypes=kVirtualMachine')
entity = [entity for entity in entities if entity['displayName'].lower() == objectname.lower()]

if len(entity) == 0:
    print('Object %s not found' % objectname)
    exit()

# find file results
encodedfilename = quote_plus(filesearch)
fileresults = api('get', '/searchfiles?entityIds=%s&filename=%s' % (entity[0]['id'], encodedfilename))

if fileresults['count'] > 10:
    print('%s results found. Please narrow your search' % fileresults['count'])
    exit()
else:
    print('\nPlease select which file to recover or press CTRL-C to exit\n')
    for idx, fileresult in enumerate(fileresults['files']):
        print('%s  %s' % (idx, fileresult['fileDocument']['filename']))

# prompt user to select file
if pyversion == 2:
    selected = raw_input('\nSelection: ')
else:
    selected = input('\nSelection: ')

if selected.isdigit() is False:
    print('Invalid selection')
    exit()
else:
    selected = int(selected)
    if selected >= len(fileresults['files']):
        print('Invalid selection')
        exit()

# gather details for download
selectedfile = fileresults['files'][selected]
clusterId = selectedfile['fileDocument']['objectId']['jobUid']['clusterId']
clusterIncarnationId = selectedfile['fileDocument']['objectId']['jobUid']['clusterIncarnationId']
jobId = selectedfile['fileDocument']['objectId']['jobUid']['objectId']
viewBoxId = selectedfile['fileDocument']['viewBoxId']
filePath = selectedfile['fileDocument']['filename']
encodedfilePath = quote_plus(filePath)
filename = os.path.split(filePath)[1]
outpath = os.path.join(destinationpath, filename)

# find versions
versions = api('get', '/file/versions?clusterId=%s&clusterIncarnationId=%s&entityId=%s&filename=%s&fromObjectSnapshotsOnly=false&jobId=%s' % (clusterId, clusterIncarnationId, entity[0]['id'], encodedfilePath, jobId))
print('\nPlease select a version of the file to recover\n')
for idx, version in enumerate(versions['versions']):
    print('%s  %s' % (idx, usecsToDate(version['instanceId']['jobStartTimeUsecs'])))

# prompt user to select version
if pyversion == 2:
    selected = raw_input('\nSelection: ')
else:
    selected = input('\nSelection: ')

if selected.isdigit() is False:
    print('Invalid selection')
    exit()
else:
    selected = int(selected)
    if selected >= len(versions['versions']):
        print('Invalid selection')
        exit()

# gather versioon info
version = versions['versions'][selected]
attemptNum = version['instanceId']['attemptNum']
jobInstanceId = version['instanceId']['jobInstanceId']
jobStartTimeUsecs = version['instanceId']['jobStartTimeUsecs']

# download the file
print('Downloading %s to %s' % (filename, destinationpath))
fileDownload('/downloadfiles?attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&filepath=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&viewBoxId=%s' % (attemptNum, clusterId, clusterIncarnationId, entity[0]['id'], encodedfilePath, jobId, jobInstanceId, jobStartTimeUsecs, viewBoxId), outpath)
