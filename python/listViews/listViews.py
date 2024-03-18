#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import timedelta

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
parser.add_argument('-n', '--name', type=str, default=None)  # Cohesity User Domain
parser.add_argument('-s', '--showsettings', action='store_true')  # view name
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib', 'tib', 'TiB'], default='GiB')  # units

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
showsettings = args.showsettings
units = args.units
name = args.name

multiplier = 1024 * 1024 * 1024 * 1024
if units.lower() == 'gib':
    multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'
if units == 'tib':
    units == 'TiB'


def timeString(msecs):
    secs = msecs / 1000
    timeSpan = timedelta(seconds=secs)
    timedays = timeSpan.days
    timehours = timeSpan.seconds // 3600
    timeminutes = (timeSpan.seconds // 60) % 60
    timesecs = (timeSpan.seconds) % 60
    duration = '%s:%02d:%02d:%02d' % (timedays, timehours, timeminutes, timesecs)
    return duration


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

views = api('get', 'views')

if views['count'] > 0:
    if name is not None:
        views = [v for v in views['views'] if v['name'].lower() == name.lower()]
        if len(views) == 0:
            print('view %s not found' % name)
            exit(1)
    else:
        views = views['views']
    if showsettings or name is not None:
        for view in sorted(views, key=lambda v: v['name'].lower()):
            if name is None or name.lower() == view['name'].lower():
                protected = False
                if 'viewProtection' in view:
                    protected = True
                print('\n                      Name: %s' % view['name'])
                print('               Create Date: %s' % usecsToDate(view['createTimeMsecs'] * 1000))
                print('            Storage Domain: %s' % view['viewBoxName'])
                print('                  Protocol: %s' % view['protocolAccess'][1:].replace('Only', ''))
                if 'nfsMountPath' in view:
                    print('            NFS Mount Path: %s' % view['nfsMountPath'])
                if 'smbMountPath' in view:
                    print('            SMB Mount Path: %s' % view['smbMountPath'])
                if 's3AccessPath' in view:
                    print('             S3 Mount Path: %s' % view['s3AccessPath'])
                print('                 Protected: %s' % protected)
                print('             Logical Usage: %s %s' % (round(view['logicalUsageBytes'] / multiplier, 2), units))
                if 'logicalQuota' in view:
                    if 'hardLimitBytes' in view['logicalQuota']:
                        print('             Logical Quota: %s %s' % (int(round(view['logicalQuota']['hardLimitBytes'] / multiplier, 0)), units))
                    if 'alertLimitBytes' in view['logicalQuota']:
                        print('               Quota Alert: %s %s' % (int(round(view['logicalQuota']['alertLimitBytes'] / multiplier, 0)), units))
                print('                QOS Policy: %s' % view['qos']['principalName'])
                if 'subnetWhitelist' in view:
                    print('                 Whitelist:')
                    entrynum = 0
                    for entry in view['subnetWhitelist']:
                        if 'nfsRootSquash' not in entry:
                            entry['nfsRootSquash'] = 'n/a'
                        if entrynum > 0:
                            print('')
                        print('                            %s/%s' % (entry['ip'], entry['netmaskBits']))
                        print('                            nfsRootSquash: %s' % entry['nfsRootSquash'])
                        print('                            nfsAccess: %s' % entry['nfsAccess'][1:])
                        print('                            smbAccess: %s' % entry['smbAccess'][1:])
                        entrynum = 1
                if 'fileLockConfig' in view:
                    print('             Datalock Mode: %s' % view['fileLockConfig'].get('mode', 'kNone')[1:])
                    if 'autoLockAfterDurationIdle' in view['fileLockConfig']:
                        autolockMins = view['fileLockConfig']['autoLockAfterDurationIdle'] / 60000
                        print('    Auto Lock Idle Minutes: %s' % autolockMins)
                    if 'defaultFileRetentionDurationMsecs' in view['fileLockConfig']:
                        defaultRetention = timeString(view['fileLockConfig']['defaultFileRetentionDurationMsecs'])
                        print('       Default Lock Period: %s' % defaultRetention)
                    print('  Manual Datalock Protocol: %s' % view['fileLockConfig'].get('lockingProtocol', 'kNone')[1:])
                    if 'minRetentionDurationMsecs' in view['fileLockConfig']:
                        minRetention = timeString(view['fileLockConfig']['minRetentionDurationMsecs'])
                        print('       Minimum Lock Period: %s' % minRetention)
                    if 'maxRetentionDurationMsecs' in view['fileLockConfig']:
                        maxRetention = timeString(view['fileLockConfig']['maxRetentionDurationMsecs'])
                        print('       Maximun Lock Period: %s' % maxRetention)
        print('')
    else:
        print('\nProto  Name')
        print('-----  ----')
        for view in sorted(views, key=lambda v: v['name'].lower()):
            if name is None or name.lower() == view['name'].lower():
                print(' %-4s  %s' % (view['protocolAccess'][1:].replace('Only', ''), view['name']))
        print('')
