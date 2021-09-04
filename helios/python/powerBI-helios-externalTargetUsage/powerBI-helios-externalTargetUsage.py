import pandas as pd
from pyhesity import *

apiKey = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

apiauth(vip='helios.cohesity.com', username='helios', domain='local', useApiKey=True, password=apiKey, quiet=True)

endMSecs = int(timeAgo(0, 'days') / 1000)
startMSecs = int(timeAgo(31, 'days') / 1000)

data = []

for hcluster in heliosClusters():
    heliosCluster(hcluster['name'])
    vaults = api('get', 'vaults')
    for vault in vaults:
        stats = api('get', 'statistics/timeSeriesStats?endTimeMsecs=%s&entityId=%s&metricName=kMorphedUsageBytes&metricUnitType=0&range=day&rollupFunction=latest&rollupIntervalSecs=86400&schemaName=kIceboxVaultStats&startTimeMsecs=%s' % (endMSecs, vault['id'], startMSecs))
        if stats is not None and 'dataPointVec' in stats and len(stats['dataPointVec']) > 0:
            consumedBytes = stats['dataPointVec'][-1]['data']['int64Value']
            data.append([hcluster['name'], vault['name'], vault['externalTargetType'][1:], round(float(consumedBytes) / (1024 * 1024 * 1024), 2)])

df = pd.DataFrame(data, columns=['ClusterName', 'TargetName', 'TargetType', 'ConsumedGiB'])
print(df)
