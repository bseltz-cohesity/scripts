#!/usr/bin/env python
"""get/set feature flags with python"""

# import pyhesity wrapper module
from pyhesity import *
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-n', '--flagname', type=str, default=None)
parser.add_argument('-r', '--reason', type=str, default=None)
parser.add_argument('-ui', '--isuifeature', action='store_true')
parser.add_argument('-x', '--clear', action='store_true')
parser.add_argument('-i', '--importfile', type=str, default=None)

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
flagname = args.flagname
reason = args.reason
isuifeature = args.isuifeature
clear = args.clear
importfile = args.importfile

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

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

cluster = api('get', 'cluster')
timestamp = int(dateToUsecs() / 1000000)


def setFeatureFlag(flagname, reason, ui=None):
    if ui is False:
        uiFeature = False
    else:
        uiFeature = True
    print('\nSetting Feature Flag: %s' % (flagname))
    flag = {
        "name": flagname,
        "isApproved": True,
        "isUiFeature": uiFeature,
        "reason": reason,
        "clear": False,
        "timestamp": timestamp
    }

    if clear is True:
        flag['clear'] = True
    else:
        if reason is None:
            print('-reason is required to set a feature flag')
            exit()

    response = api('put', 'clusters/feature-flag', flag, v=2)


# set a flag
if flagname is not None:
    setFeatureFlag(flagname=flagname, reason=reason, ui=isuifeature)
elif importfile is not None:
    # import flags fom export file
    flagdata = []
    f = codecs.open(importfile, 'r', 'utf-8')
    flagdata += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
    for f in flagdata[1:]:
        (flagname, ui, approved, reason) = f.split(',', 3)
        reason = reason.split(',')[0]
        if ui.upper() == 'FALSE':
            ui = False
        else:
            ui = True
        setFeatureFlag(flagname=flagname, reason=reason, ui=ui)

# write gflags to export file
print('\nCurrent Feature Flags:')
exportfile = 'featureFlags-%s.csv' % cluster['name']
f = codecs.open(exportfile, 'w', 'utf-8')
f.write('Flag Name,is UI Feature,is Approved,Reason,Timestamp\n')

# get currrent flags
flags = api('get', 'clusters/feature-flag', v=2)

if flags is not None and len(flags) > 0:
    for flag in sorted(flags, key=lambda f: f['name'].lower()):
        print('')
        print('        name: %s' % flag['name'])
        print(' isUiFeature: %s' % flag['isUiFeature'])
        print('  isApproved: %s' % flag['isApproved'])
        print('      reason: %s' % flag['reason'])
        print('   timestamp: %s' % usecsToDate(int(flag['timestamp'] * 1000000)))
        f.write('%s,%s,%s,%s,%s\n' % (flag['name'], flag['isUiFeature'], flag['isApproved'], flag['reason'], usecsToDate(int(flag['timestamp'] * 1000000))))

f.close()

print('\nfeature flags saved to %s\n' % exportfile)
