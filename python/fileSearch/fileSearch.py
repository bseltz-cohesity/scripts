#!/usr/bin/env python
"""search for files using python"""

# version 2021.02.23

# usage: ./backedUpFileList.py -v mycluster \
#                              -u myuser \
#                              -d mydomain.net \
#                              -s server1.mydomain.net \
#                              -j myjob \
#                              -f '2020-06-29 12:00:00'

# import pyhesity wrapper module
from pyhesity import *
# from datetime import datetime
# import codecs
import sys
import argparse
if sys.version_info.major >= 3 and sys.version_info.minor >= 5:
    from urllib.parse import quote_plus
else:
    from urllib import quote_plus

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)     # optional password
parser.add_argument('-p', '--filepath', type=str, required=True)     # optional password
parser.add_argument('-s', '--sourceserver', type=str, default=None)  # name of source server
parser.add_argument('-j', '--jobname', type=str, default=None)       # narrow search by job name
parser.add_argument('-t', '--jobtype', type=str, choices=['VMware', 'Physical', None], default=None)
parser.add_argument('-x', '--showversions', type=int, default=None)       # narrow search by job name

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
filepath = args.filepath
sourceserver = args.sourceserver
jobname = args.jobname
jobtype = args.jobtype
showversions = args.showversions

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

jobs = api('get', 'protectionJobs')

encodedFile = quote_plus(filepath)

searchUrl = '/searchfiles?filename=%s' % encodedFile

if jobname is not None:
    job = [j for j in jobs if j['name'].lower() == jobname.lower()]
    if len(job) == 0:
        print('Job %s not found' % jobname)
        exit()
    else:
        searchUrl = '%s&jobIds=%s' % (searchUrl, job[0]['id'])

if jobtype is not None:
    searchUrl = '%s&entityTypes=k%s' % (searchUrl, jobtype)

search = api('get', searchUrl)

print('')
x = 0
if search is not None and 'files' in search and len(search['files']) > 0:
    for file in search['files']:
        job = [j for j in jobs if j['id'] == file['fileDocument']['objectId']['jobId']]
        if len(job) > 0:
            if sourceserver is None or file['fileDocument']['objectId']['entity']['displayName'].lower() == sourceserver.lower():
                x += 1
                print('%s: %s / %s -> %s' % (x, job[0]['name'], file['fileDocument']['objectId']['entity']['displayName'], file['fileDocument']['filename']))
                if showversions == x:
                    clusterId = file['fileDocument']['objectId']['jobUid']['clusterId']
                    clusterIncarnationId = file['fileDocument']['objectId']['jobUid']['clusterIncarnationId']
                    entityId = file['fileDocument']['objectId']['entity']['id']
                    jobId = file['fileDocument']['objectId']['jobId']
                    versions = api('get', '/file/versions?clusterId=%s&clusterIncarnationId=%s&entityId=%s&filename=%s&fromObjectSnapshotsOnly=false&jobId=%s' % (clusterId, clusterIncarnationId, entityId, encodedFile, jobId))
                    if versions is not None and 'versions' in versions and len(versions['versions']) > 0:
                        print('\n%10s  %s' % ('runId', 'runDate'))
                        print('%10s  %s' % ('-----', '-------'))
                        for version in versions['versions']:
                            print('%10d  %s' % (version['instanceId']['jobInstanceId'], usecsToDate(version['instanceId']['jobStartTimeUsecs'])))

if showversions is None:
    print('\n%s files found' % x)
else:
    print('')
