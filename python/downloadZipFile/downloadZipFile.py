#!/usr/bin/env python
"""Download files from Cohesity backups using Python"""

# usage: ./downloadFile.py -v mycluster -u myusername -d mydomain.net -o myserver -f 'mypath/myfile' -p /Users/myusername/Downloads

from pyhesity import *
import zipfile
import os
# from urllib import quote_plus
# import sys
# import os

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--recoveryname', type=str, required=True)
parser.add_argument('-t', '--tempdir', type=str, default=None)
parser.add_argument('-r', '--recoverydir', type=str, required=True)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
recoveryname = args.recoveryname
tempdir = args.tempdir
recoverydir = args.recoverydir

# temp dir to download zip file
if tempdir is None:
    SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))
    tempdir = os.path.join(SCRIPTDIR, 'tmp')
if os.path.isdir(tempdir) is False:
    try:
        os.mkdir(tempdir)
    except Exception:
        print('error accessing temp dir %s' % tempdir)
        exit(1)

# recovery dir to extract to (typically /)
if os.path.isdir(recoverydir) is False:
    try:
        os.mkdir(recoverydir)
    except Exception:
        print('error accessing recovery dir %s' % recoverydir)
        exit(1)

# path of downloaded zip file
zipfilePath = os.path.join(tempdir, 'Download.zip')

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# find recovery task
recoveries = api('get', 'data-protect/recoveries?startTimeUsecs=%s&snapshotTargetType=Archival&recoveryActions=DownloadFilesAndFolders&includeTenants=true&endTimeUsecs=%s&archivalTargetType=Cloud,Nas' % (timeAgo(31, 'days'), timeAgo(1, 'seconds')), v=2)
if recoveries is not None and 'recoveries' in recoveries and len(recoveries['recoveries']) > 0:
    recovery = [r for r in recoveries['recoveries'] if r['name'].lower() == recoveryname.lower()]
    if recovery is None or len(recovery) == 0:
        print('Recovery: %s not found' % recoveryname)
        exit(1)
    else:
        recovery = recovery[0]
        # download zip file
        downloadUrl = 'data-protect/recoveries/%s/downloadFiles?' % recovery['id']
        print('Downloading zip file...')
        fileDownload(downloadUrl, fileName=zipfilePath, v=2)
        # extract zip file
        print('Extracting zip file to %s...' % recoverydir)
        with zipfile.ZipFile(zipfilePath, 'r') as zip_ref:
            zip_ref.extractall(recoverydir)
        # remove zip file
        os.remove(zipfilePath)
