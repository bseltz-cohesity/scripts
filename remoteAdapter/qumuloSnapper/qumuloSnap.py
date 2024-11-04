#!/usr/bin/env python
"""qumulo snapper"""

import requests
import json
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-q', '--qumulo', type=str, required=True)
parser.add_argument('-qu', '--qumulo_user', type=str, required=True)
parser.add_argument('-qp', '--qumulo_passwd', type=str, default=None)
parser.add_argument('-s', '--snapsuffix', type=str, default='cohesity')
parser.add_argument('-su', '--smbusername', type=str, required=True)
parser.add_argument('-sp', '--smbpasswd', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
jobname = args.jobname
qumulo = args.qumulo
qumulo_user = args.qumulo_user
qumulo_passwd = args.qumulo_passwd
snapsuffix = args.snapsuffix
smbusername = args.smbusername
smbpasswd = args.smbpasswd

requests.packages.urllib3.disable_warnings()

# authenticate
print('*** authenticating to Cohesity: %s at %s' % (username, vip))
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

if qumulo_passwd is None:
    print('Getting password for qumulo user: %s' % qumulo_user)
    qumulo_passwd = pw(vip=qumulo, username=qumulo_user)
if smbpasswd is None:
    print('Getting password for SMB user: %s' % smbusername)
    smbpasswd = pw(vip=vip, username=smbusername)


sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true')

finishedStates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']

# get protection job
jobs = api('get', 'data-protect/protection-groups?environments=kGenericNas&isActive=true&isDeleted=false&includeLastRunInfo=true', v=2)
if jobs is not None and 'protectionGroups' in jobs and len(jobs['protectionGroups']) > 0:
    job = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if job is not None and len(job) > 0:
        job = job[0]
        if 'lastRun' in job and 'localBackupInfo' in job['lastRun'] and 'status' in job['lastRun']['localBackupInfo']:
            if job['lastRun']['localBackupInfo']['status'] not in finishedStates:
                print('Job is already running')
                exit(1)
    else:
        print('Job %s not found' % jobname)
        exit(1)

# qumulo rest api setup
header = {"accept": "application/json",
          "content-type": "application/json"}

# authenticate to qumulo
creds = json.dumps({"password": qumulo_passwd,
                    "username": qumulo_user})

print('*** authenticating to qumulo')
response = requests.post('https://%s:8000/v1/session/login' % qumulo, data=creds, headers=header, verify=False)
header['Authorization'] = 'Bearer %s' % response.json()['bearer_token']

# get qumulo SMB shares
print('*** getting smb share info')
smbshares = (requests.get('https://%s:8000/v2/smb/shares/' % qumulo, headers=header, verify=False)).json()
nfsexports = (requests.get('https://%s:8000/v2/nfs/exports/' % qumulo, headers=header, verify=False)).json()

for o in job['genericNasParams']['objects']:
    smb = False
    sourceInfo = api('get', '/backupsources?allUnderHierarchy=true&entityId=%s&onlyReturnOneLevel=true' % o['id'])
    mountpath = sourceInfo['entityHierarchy']['entity']['genericNasEntity']['path']
    # parse fspath and current snap id
    if '\\' in mountpath:
        smb = True
        share_name = mountpath.split('\\', 3)[3].split('\\.snapshot')[0]
        snapidparts = mountpath.split('\\.snapshot\\')
    else:
        share_name = '/' + mountpath.split('/', 2)[1].split('/.snapshot')[0]
        snapidparts = mountpath.split('/.snapshot/')
    # get share
    if smb is True:
        if smbshares is not None and len(smbshares) > 0:
            share = [s for s in smbshares if s['share_name'].lower() == share_name.lower()]
            if share is not None and len(share) > 0:
                share = share[0]
                sharepath = share['fs_path'].replace('/', '%2F')
                fileinfo = (requests.get('https://%s:8000/v1/files/%s/info/attributes' % (qumulo, sharepath), headers=header, verify=False)).json()
                fs_id = fileinfo['id']
            else:
                print('Share %s not found' % share_name)
                continue
        else:
            print('no smb shares found')
            continue
    else:
        if nfsexports is not None and len(nfsexports) > 0:
            export = [e for e in nfsexports if e['export_path'].lower() == share_name.lower()]
            if export is not None and len(export) > 0:
                share = export[0]
                share_name = share['export_path']
                sharepath = share['fs_path'].replace('/', '%2F')
                fileinfo = (requests.get('https://%s:8000/v1/files/%s/info/attributes' % (qumulo, sharepath), headers=header, verify=False)).json()
                fs_id = fileinfo['id']
            else:
                print('Share %s not found' % share_name)
                continue
        else:
            print('no smb shares found')
            continue

    # delete existing snapshots
    print('*** deleting existing snapshots')
    snaps = (requests.get('https://%s:8000/v3/snapshots/?filter=all' % qumulo, headers=header, verify=False)).json()
    if snaps is not None and 'entries' in snaps and len(snaps['entries']) > 0:
        snaps = [s for s in snaps['entries'] if s['source_file_id'] == fs_id]
        for snap in snaps:
            if snapsuffix.lower() in snap['name'].lower():
                deletesnap = (requests.delete('https://%s:8000/v3/snapshots/%s' % (qumulo, snap['id']), headers=header, verify=False)).json()

    # create new snapshot
    newsnap = (requests.post('https://%s:8000/v3/snapshots/' % qumulo, data=json.dumps({"source_file_id": fs_id, "name_suffix": snapsuffix}), headers=header, verify=False)).json()
    newsnapname = newsnap['name']
    print('*** creating new snapshot: %s' % newsnap['name'])

    if smb is True:
        newmountpath = '%s\\.snapshot\\%s' % (snapidparts[0], newsnapname)
    else:
        newmountpath = '%s/.snapshot/%s' % (snapidparts[0], newsnapname)

    print('*** finding NAS protection source')
    mySource = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == mountpath.lower()]

    if len(mySource) == 0:
        print('NAS source %s not found!' % mountpath)
        continue
    else:
        mySource = mySource[0]

    sourceInfo = api('get', '/backupsources?allUnderHierarchy=true&entityId=%s&onlyReturnOneLevel=true' % mySource['rootNode']['id'])

    # update protection source
    updateParams = {
        "entity": sourceInfo['entityHierarchy']['entity'],
        "entityInfo": sourceInfo['entityHierarchy']['registeredEntityInfo']['connectorParams']
    }
    updateParams['entity']['displayName'] = newmountpath
    updateParams['entity']['genericNasEntity']['path'] = newmountpath
    updateParams['entityInfo']['endPoint'] = newmountpath
    updateParams['entityInfo']['entity']['displayName'] = newmountpath
    updateParams['entityInfo']['entity']['genericNasEntity']['path'] = newmountpath
    if smb is True:
        updateParams['entityInfo']['credentials']['nasMountCredentials']['password'] = smbpasswd

    print('*** updating protection source with new mount path: %s' % newmountpath)
    response = api('put', '/backupsources/%s' % mySource['rootNode']['id'], updateParams)
