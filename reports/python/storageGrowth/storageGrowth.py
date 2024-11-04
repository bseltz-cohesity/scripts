#!/usr/bin/env python
"""Storage Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-y', '--days', type=int, default=None)
parser.add_argument('-x', '--units', type=str, choices=['GiB', 'TiB', 'gib', 'tib'], default='GiB')

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
folder = args.outfolder
useApiKey = args.useApiKey
days = args.days
units = args.units

if units.lower() == 'tib':
    units = 'TiB'
    multiplier = 1024 * 1024 * 1024 * 1024
if units.lower() == 'gib':
    units = 'GiB'
    multiplier = 1024 * 1024 * 1024

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

cluster = api('get', 'cluster')

now = datetime.now()
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/storageReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write("Date,Consumed (%s),Capacity (%s),PCT Full\n" % (units, units))

if days is not None:
    startTimeMsecs = int(timeAgo(days, 'days') / 1000)
else:
    startTimeMsecs = cluster['createdTimeMsecs']

print('Collecting report data...')

consumptionStats = api('get', 'statistics/timeSeriesStats?schemaName=kBridgeClusterStats&entityId=%s&metricName=kMorphedUsageBytes&startTimeMsecs=%s&rollupFunction=latest&rollupIntervalSecs=86400' % (cluster['id'], startTimeMsecs))
capacityStats = api('get', 'statistics/timeSeriesStats?schemaName=kBridgeClusterStats&entityId=%s&metricName=kCapacityBytes&startTimeMsecs=%s&rollupFunction=latest&rollupIntervalSecs=86400' % (cluster['id'], startTimeMsecs))

statsConsumed = {}
for stat in consumptionStats['dataPointVec']:
    dt = datetime.strptime(usecsToDate(stat['timestampMsecs'] * 1000), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d')
    consumed = stat['data']['int64Value'] / multiplier
    statsConsumed[dt] = round(consumed, 1)

statsCapacity = {}
for stat in capacityStats['dataPointVec']:
    dt = datetime.strptime(usecsToDate(stat['timestampMsecs'] * 1000), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d')
    capacity = stat['data']['int64Value'] / multiplier
    statsCapacity[dt] = round(capacity, 1)

for dt in sorted(statsConsumed, reverse=True):
    pctFull = round(100 * statsConsumed[dt] / statsCapacity[dt], 1)
    print('%s, %s, %s, %s' % (dt, statsConsumed[dt], statsCapacity[dt], pctFull))
    csv.write('%s,%s,%s,%s\n' % (dt, statsConsumed[dt], statsCapacity[dt], pctFull))

csv.close()
print('Output written to %s' % csvfileName)
