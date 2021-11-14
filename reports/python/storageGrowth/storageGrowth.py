#!/usr/bin/env python
"""Storage Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-x', '--days', type=int, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
useApiKey = args.useApiKey
days = args.days

GiB = (1024 * 1024 * 1024)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')

now = datetime.now()
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/storageReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write("Date,Consumed (GiB),Capacity (GiB),PCT Full\n")

if days is not None:
    startTimeMsecs = timeAgo(days, 'days') / 1000
else:
    startTimeMsecs = cluster['createdTimeMsecs']

print('Collecting report data...')

consumptionStats = api('get', 'statistics/timeSeriesStats?schemaName=kBridgeClusterStats&entityId=%s&metricName=kMorphedUsageBytes&startTimeMsecs=%s&rollupFunction=average&rollupIntervalSecs=86400' % (cluster['id'], startTimeMsecs))
capacityStats = api('get', 'statistics/timeSeriesStats?schemaName=kBridgeClusterStats&entityId=%s&metricName=kCapacityBytes&startTimeMsecs=%s&rollupFunction=average&rollupIntervalSecs=86400' % (cluster['id'], startTimeMsecs))

statsConsumed = {}
for stat in consumptionStats['dataPointVec']:
    dt = datetime.strptime(usecsToDate(stat['timestampMsecs'] * 1000), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d')
    consumed = stat['data']['int64Value'] / GiB
    statsConsumed[dt] = round(consumed)

statsCapacity = {}
for stat in capacityStats['dataPointVec']:
    dt = datetime.strptime(usecsToDate(stat['timestampMsecs'] * 1000), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d')
    capacity = stat['data']['int64Value'] / GiB
    statsCapacity[dt] = round(capacity)

for dt in sorted(statsConsumed, reverse=True):
    pctFull = round(100 * statsConsumed[dt] / statsCapacity[dt])
    print('%s,%s,%s,%s' % (dt, int(statsConsumed[dt]), int(statsCapacity[dt]), int(pctFull)))
    csv.write('%s,%s,%s,%s\n' % (dt, int(statsConsumed[dt]), int(statsCapacity[dt]), int(pctFull)))

csv.close()
print('Output written to %s' % csvfileName)
