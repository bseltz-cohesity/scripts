#!/usr/bin/env python
"""cluster storage stats for python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')  # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-n', '--unit', type=str, choices=['GiB', 'TiB', 'gib', 'tib'], default='TiB')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
unit = args.unit

if unit.lower() == 'tib':
    multiplier = 1024 * 1024 * 1024 * 1024
    unit = 'TiB'
else:
    multiplier = 1024 * 1024 * 1024
    unit = 'GiB'


def toUnits(value):
    return round(float(value) / multiplier, 1)


# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=True, noretry=True)

# outfile
now = datetime.now()
# cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'heliosStorageStats-%s.csv' % dateString
f = codecs.open(outfile, 'w')

# headings
f.write('Date,Capacity (%s),Consumed (%s),Free (%s),Used %%,Data In (%s),Data Written (%s),Storage Reduction,Data Reduction\n' % (unit, unit, unit, unit, unit))

stats = {}


def parseStats(clusterName, dataPoint, statName):
    if clusterName not in stats.keys():
        stats[clusterName] = {}
    stats[clusterName][statName] = dataPoint['data']['int64Value']


endMsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S")) / 1000
startMsecs = (timeAgo(2, 'days')) / 1000

print('\nGathering cluster stats:\n')

for cluster in heliosClusters():
    heliosCluster(cluster)
    print('    %s' % cluster['name'])
    capacityStats = api('get', 'statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kCapacityBytes&metricUnitType=0&range=day&rollupFunction=average&rollupIntervalSecs=86400&schemaName=kBridgeClusterStats&startTimeMsecs=%s' % (endMsecs, cluster['clusterId'], startMsecs))
    consumedStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=kBridgeClusterTierPhysicalStats&metricName=kMorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s:Local&endTimeMsecs=%s' % (startMsecs, cluster['clusterId'], endMsecs))
    dataInStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=ApolloV2ClusterStats&metricName=BrickBytesLogical&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s (ID %s)&endTimeMsecs=%s' % (startMsecs, cluster['name'], cluster['clusterId'], endMsecs))
    dataWrittenStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=ApolloV2ClusterStats&metricName=ChunkBytesMorphed&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s (ID %s)&endTimeMsecs=%s' % (startMsecs, cluster['name'], cluster['clusterId'], endMsecs))
    logicalSizeStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=kBridgeClusterLogicalStats&metricName=kUnmorphedUsageBytes&rollupIntervalSecs=86400&rollupFunction=latest&entityIdList=%s&endTimeMsecs=%s' % (startMsecs, cluster['clusterId'], endMsecs))

    parseStats(cluster['name'], capacityStats['dataPointVec'][0], 'capacity')
    parseStats(cluster['name'], consumedStats['dataPointVec'][0], 'consumed')
    parseStats(cluster['name'], dataInStats['dataPointVec'][0], 'dataIn')
    parseStats(cluster['name'], dataWrittenStats['dataPointVec'][0], 'dataWritten')
    parseStats(cluster['name'], logicalSizeStats['dataPointVec'][0], 'logicalSize')

for clusterName in sorted(stats.keys()):
    capacity = stats[clusterName]['capacity']
    consumed = stats[clusterName]['consumed']
    dataIn = stats[clusterName]['dataIn']
    dataWritten = stats[clusterName]['dataWritten']
    logicalSize = stats[clusterName]['logicalSize']
    free = capacity - consumed
    pctUsed = round(100 * consumed / capacity, 0)
    storageReduction = round(float(logicalSize) / consumed, 1)
    dataReduction = round(float(dataIn) / dataWritten, 1)
    f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (clusterName, toUnits(capacity), toUnits(consumed), toUnits(free), pctUsed, toUnits(dataIn), toUnits(dataWritten), storageReduction, dataReduction))

f.close()
print('\nOutput saved to %s\n' % outfile)
