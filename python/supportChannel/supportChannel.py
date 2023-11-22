#!/usr/bin/env python

from pyhesity import *
from time import sleep
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
parser.add_argument('-e', '--enable', action='store_true')
parser.add_argument('-x', '--disable', action='store_true')
parser.add_argument('-y', '--days', type=int, default=1)

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
enable = args.enable
disable = args.disable
days = args.days

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

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

cluster = api('get', 'cluster')
isRTEnabled = cluster['reverseTunnelEnabled']

if enable:
    endDateUsecs = timeAgo(-days, 'days')
    endDate = usecsToDate(endDateUsecs)
    endDateMsecs = int(endDateUsecs / 1000)
    print('\nEnabling Support Channel until %s...\n' % endDate)
    rtParams = {
        "enableReverseTunnel": True,
        "reverseTunnelEnableEndTimeMsecs": endDateMsecs
    }
    result = api('put', '/reverseTunnel', rtParams)
elif disable:
    print('\nDisabling Support Channel...\n')
    rtParams = {
        "enableReverseTunnel": False,
        "reverseTunnelEnableEndTimeMsecs": 0
    }
    result = api('put', '/reverseTunnel', rtParams)
else:
    if isRTEnabled:
        endDate = usecsToDate(cluster['reverseTunnelEndTimeMsecs'] * 1000)
        print('\nSupport Channel is enabled until %s\n' % endDate)
    else:
        print('\nSupport Channel is disabled\n')

if not disable and (enable or isRTEnabled is True):
    supportUserToken = ''
    while supportUserToken == '':
        if enable:
            sleep(2)
        linuxUser = api('put', 'users/linuxSupportUserBashShellAccess')
        supportUserToken = linuxUser['supportUserToken']
    print('Please provide the below to Cohesity Support')
    print('\nCluster ID and Token for Cluster: %s (expires %s\n%s %s\n' % (cluster['name'], endDate, cluster['id'], supportUserToken))
