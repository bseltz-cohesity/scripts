#!/usr/bin/env python
"""cluster storage stats for python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-n', '--unit', type=str, choices=['GiB', 'TiB', 'gib', 'tib'], default='TiB')
parser.add_argument('-y', '--days', type=int, default=31)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
unit = args.unit
days = args.days


if unit.lower() == 'tib':
    multiplier = 1024 * 1024 * 1024 * 1024
    unit = 'TiB'
else:
    multiplier = 1024 * 1024 * 1024
    unit = 'GiB'


def toUnits(value):
    return round(float(value) / multiplier, 1)


# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

# outfile
now = datetime.now()
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'clusterStorageStats-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Date,Capacity (%s),Consumed (%s),Free (%s),Used %%,Data In (%s),Data Written (%s),Storage Reduction,Data Reduction\n' % (unit, unit, unit, unit, unit))

endMsecs = int(dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S")) / 1000)
startMsecs = int((timeAgo(days, 'days')) / 1000)

capacityStats = api('get', 'statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kCapacityBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=86400&schemaName=kBridgeClusterStats&startTimeMsecs=%s' % (endMsecs, cluster['id'], startMsecs))
consumedStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=kBridgeClusterTierPhysicalStats&metricName=kMorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s:Local&endTimeMsecs=%s' % (startMsecs, cluster['id'], endMsecs))
dataInStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=ApolloV2ClusterStats&metricName=BrickBytesLogical&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s (ID %s)&endTimeMsecs=%s' % (startMsecs, cluster['name'], cluster['id'], endMsecs))
dataWrittenStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=ApolloV2ClusterStats&metricName=ChunkBytesMorphed&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s (ID %s)&endTimeMsecs=%s' % (startMsecs, cluster['name'], cluster['id'], endMsecs))
logicalSizeStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=kBridgeClusterLogicalStats&metricName=kUnmorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s&endTimeMsecs=%s' % (startMsecs, cluster['id'], endMsecs))

stats = {}


def parseStats(dataPoints, statName):
    for stat in dataPoints:
        value = stat['data']['int64Value']
        date = datetime.strptime(usecsToDate(stat['timestampMsecs'] * 1000), '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d')
        if date not in stats.keys():
            stats[date] = {}
        stats[date][statName] = value


parseStats(capacityStats['dataPointVec'], 'capacity')
parseStats(consumedStats['dataPointVec'], 'consumed')
parseStats(dataInStats['dataPointVec'], 'dataIn')
parseStats(dataWrittenStats['dataPointVec'], 'dataWritten')
parseStats(logicalSizeStats['dataPointVec'], 'logicalSize')

lastStatReported = False
for date in sorted(stats.keys(), reverse=True):
    capacity = stats[date]['capacity']
    consumed = stats[date]['consumed']
    dataIn = stats[date]['dataIn']
    dataWritten = stats[date]['dataWritten']
    logicalSize = stats[date]['logicalSize']
    free = capacity - consumed
    pctUsed = round(100 * consumed / capacity, 0)
    storageReduction = round(float(logicalSize) / consumed, 1)
    dataReduction = round(float(dataIn) / dataWritten, 1)
    if lastStatReported is not True:
        lastStatReported = True
        print('\nStats for %s:\n' % cluster['name'])
        print('         Capacity: %s %s' % (toUnits(capacity), unit))
        print('         Consumed: %s %s' % (toUnits(consumed), unit))
        print('             Free: %s %s' % (toUnits(free), unit))
        print('     Percent Used: %s%%' % pctUsed)
        print('Storage Reduction: %sx' % storageReduction)
        print('   Data Reduction: %sx' % dataReduction)

    f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (date, toUnits(capacity), toUnits(consumed), toUnits(free), pctUsed, toUnits(dataIn), toUnits(dataWritten), storageReduction, dataReduction))

f.close()
print('\nOutput saved to %s\n' % outfile)
