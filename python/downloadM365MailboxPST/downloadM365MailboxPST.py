#!/usr/bin/env python

from pyhesity import *
from datetime import datetime
from time import sleep
import getpass
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
parser.add_argument('-s', '--sourceusername', action='append', type=str)
parser.add_argument('-l', '--sourceuserlist', type=str)
parser.add_argument('-w', '--pstpassword', type=str)
parser.add_argument('-r', '--recoverdate', type=str, default=None)
parser.add_argument('-f', '--filename', type=str, default='pst.zip')
parser.add_argument('-x', '--continueonerror', action='store_true')
parser.add_argument('-z', '--sleeptimeseconds', type=int, default=30)
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
sourceusername = args.sourceusername
sourceuserlist = args.sourceuserlist
pstpassword = args.pstpassword
recoverdate = args.recoverdate
filename = args.filename
continueonerror = args.continueonerror
sleeptimeseconds = args.sleeptimeseconds

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


# gather server list
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
        print('*** No %s specified ***' % name)
        exit(1)
    return items


sourceusernames = gatherList(sourceusername, sourceuserlist, name='source users', required=True)

if pstpassword is None:
    pstpassword = '1'
    confirmPassword = '2'
    while pstpassword != confirmPassword:
        pstpassword = getpass.getpass("  Enter PST password: ")
        confirmPassword = getpass.getpass("Confirm PST password: ")
        if pstpassword != confirmPassword:
            print('Passwords do not match')

cluster = api('get', 'cluster')

taskName = "Recover_Mailboxes_%s" % datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

recoveryParams = {
    "name": taskName,
    "snapshotEnvironment": "kO365",
    "office365Params": {
        "recoveryAction": "ConvertToPst",
        "recoverMailboxParams": {
            "continueOnError": True,
            "skipRecoverArchiveMailbox": True,
            "skipRecoverRecoverableItems": True,
            "skipRecoverArchiveRecoverableItems": True,
            "objects": [],
            "pstParams": {
                "password": pstpassword
            }
        }
    }
}

for sourceUser in sourceusernames:
    userSearch = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverMailbox&searchString=%s&environments=kO365' % sourceUser, v=2)
    userObjs = [o for o in userSearch['objects'] if o['name'].lower() == sourceUser.lower() or o['uuid'].lower() == sourceUser.lower()]
    if userSearch is not None and 'objects' in userSearch and userSearch['objects'] is not None and len(userSearch['objects']) > 0 and userObjs is None or len(userObjs) == 0:
        for userObj in userSearch['objects']:
            userSource = api('get', 'protectionSources/objects/%s' % userObj['id'])
            if userSource is not None and userSource['office365ProtectionSource']['primarySMTPAddress'].lower() == sourceUser.lower():
                userObjs = [userObj]
    if userObjs is None or len(userObjs) == 0:
        print('*** Mailbox User %s not found ***' % sourceUser)
        if continueonerror is True:
            continue
        else:
            exit(1)

    for userObj in userObjs:
        protectionGroupId = userObj['latestSnapshotsInfo'][0]['protectionGroupId']
        snapshotId = userObj['latestSnapshotsInfo'][0]['localSnapshotInfo']['snapshotId']

        if recoverdate is not None:
            recoverDateUsecs = dateToUsecs(recoverdate) + 60000000
            snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (userObj['id'], protectionGroupId), v=2)
            snapshots = [s for s in sorted(snapshots['snapshots'], key=lambda snap: snap['runStartTimeUsecs'], reverse=True) if s['runStartTimeUsecs'] < recoverDateUsecs]
            if snapshots is not None and len(snapshots) > 0:
                snapshot = snapshots[0]
                snapshotId = snapshot['id']
            else:
                print('*** No snapshots available for %s from specified date ***' % sourceUser)
                if continueonerror is True:
                    continue
                else:
                    exit(1)

        print('==> Processing %s' % sourceUser)
        recoveryParams['office365Params']['recoverMailboxParams']['objects'].append({
            "mailboxParams": {
                "recoverFolders": None,
                "recoverEntireMailbox": True
            },
            "ownerInfo": {
                "snapshotId": snapshotId
            }
        })

if len(recoveryParams['office365Params']['recoverMailboxParams']['objects']) == 0:
    print('*** No objects found, exiting ***')
    exit(1)

recovery = api('post', 'data-protect/recoveries', recoveryParams, v=2)

# wait for restores to complete
print('==> Waiting for PST conversion to complete...')
finishedStates = ['Canceled', 'Succeeded', 'Failed']
status = 'unknown'
while status not in finishedStates:
    sleep(sleeptimeseconds)
    recoveryTask = api('get', 'data-protect/recoveries/%s?includeTenants=true' % recovery['id'], v=2)
    status = recoveryTask['status']

downloadURL = "https://%s/v2/data-protect/recoveries/%s/downloadFiles?clusterId=%s&includeTenants=true" % (vip, recovery['id'], cluster['id'])
if status == 'Succeeded':
    print('==> PST conversion finished with status: %s' % status)
    print('==> Downloading zip file to %s' % filename)
    fileDownload(uri=downloadURL, fileName=filename)
else:
    print('*** PST conversion finished with status: %s ***' % status)
