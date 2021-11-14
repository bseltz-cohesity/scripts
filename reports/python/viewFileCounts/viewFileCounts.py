#!/usr/bin/env python
"""List View File and Folder Counts Using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain

# authenticate
apiauth(vip, username, domain)

cluster = api('get', 'cluster')
now = datetime.now()
datestring = now.strftime("%Y-%m-%d")
csvfileName = 'ViewFileCounts-%s-%s.csv' % (cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write("View Name,Folders,Files\n")

endMsecs = int(dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S")) / 1000)
startMsecs = int(endMsecs - 172800000)  # 48 hours ago

views = api('get', 'views')

if views['count'] > 0:

    for view in sorted(views['views'], key=lambda v: v['name'].lower()):
        consumer = api('get', 'stats/consumers?consumerType=kViews&consumerIdList=%s' % view['viewId'])
        if consumer is not None and 'statsList' in consumer and consumer['statsList'] is not None and len(consumer['statsList']) > 0 and 'groupList' in consumer['statsList'][0] and consumer['statsList'][0] is not None and len(consumer['statsList'][0]['groupList']) > 0 and 'entityId' in consumer['statsList'][0]['groupList'][0]:
            entityId = consumer['statsList'][0]['groupList'][0]['entityId']
            folderStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=BookKeeperStats&metricName=NumDirectories&rollupIntervalSecs=21600&rollupFunction=latest&entityIdList=%s&endTimeMsecs=%s' % (startMsecs, entityId, endMsecs))
            if folderStats is not None and 'dataPointVec' in folderStats and len(folderStats['dataPointVec']) > 0:
                numDirectories = folderStats['dataPointVec'][0]['data']['int64Value']
            else:
                numDirectories = 0
            fileStats = api('get', 'statistics/timeSeriesStats?startTimeMsecs=%s&schemaName=BookKeeperStats&metricName=NumFiles&rollupIntervalSecs=21600&rollupFunction=latest&entityIdList=%s&endTimeMsecs=%s' % (startMsecs, entityId, endMsecs))
            if fileStats is not None and 'dataPointVec' in fileStats and len(fileStats['dataPointVec']) > 0:
                numFiles = fileStats['dataPointVec'][0]['data']['int64Value']
            else:
                numFiles = 0
        else:
            numFiles = 0
            numDirectories = 0

        print('%-25s  %s/%s' % (view['name'], numDirectories, numFiles))
        csv.write('%s,%s,%s\n' % (view['name'], numDirectories, numFiles))

csv.close()
print('Output saved to %s' % csvfileName)
