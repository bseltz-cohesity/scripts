#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

# import pyhesity wrapper module
from pyhesity import *

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-n', '--name', type=str, default=None)  # Cohesity User Domain
parser.add_argument('-s', '--showsettings', action='store_true')  # view name
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')  # units

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
showsettings = args.showsettings
units = args.units
name = args.name

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

# authenticate
apiauth(vip, username, domain)

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
                print('\n           name: %s' % view['name'])
                print('    create date: %s' % usecsToDate(view['createTimeMsecs'] * 1000))
                print(' Storage Domain: %s' % view['viewBoxName'])
                print('       protocol: %s' % view['protocolAccess'][1:].replace('Only', ''))
                if 'nfsMountPath' in view:
                    print(' NFS mount path: %s' % view['nfsMountPath'])
                if 'smbMountPath' in view:
                    print(' SMB mount path: %s' % view['smbMountPath'])
                if 's3AccessPath' in view:
                    print('  S3 mount path: %s' % view['s3AccessPath'])
                print('      protected: %s' % protected)
                print('  logical usage: %s %s' % (round(view['logicalUsageBytes'] / multiplier, 2), units))
                if 'logicalQuota' in view:
                    print('  logical quota: %s %s' % (int(round(view['logicalQuota']['hardLimitBytes'] / multiplier, 0)), units))
                    print('    quota alert: %s %s' % (int(round(view['logicalQuota']['alertLimitBytes'] / multiplier, 0)), units))
                print('     QOS Policy: %s' % view['qos']['principalName'])
                if 'subnetWhitelist' in view:
                    print('      whitelist:')
                    entrynum = 0
                    for entry in view['subnetWhitelist']:
                        if 'nfsRootSquash' not in entry:
                            entry['nfsRootSquash'] = 'n/a'
                        if entrynum > 0:
                            print('')
                        print('                 %s/%s' % (entry['ip'], entry['netmaskBits']))
                        print('                 nfsRootSquash: %s' % entry['nfsRootSquash'])
                        print('                 nfsAccess: %s' % entry['nfsAccess'][1:])
                        print('                 smbAccess: %s' % entry['smbAccess'][1:])
                        entrynum = 1
        print('')
    else:
        print('\nProto  Name')
        print('-----  ----')
        for view in sorted(views, key=lambda v: v['name'].lower()):
            if name is None or name.lower() == view['name'].lower():
                print(' %-4s  %s' % (view['protocolAccess'][1:].replace('Only', ''), view['name']))
        print('')
