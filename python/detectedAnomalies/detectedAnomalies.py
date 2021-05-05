#!/usr/bin/env python

from pyhesity import *
from datetime import datetime

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, required=True)  # username

args = parser.parse_args()

username = args.username

apiauth(username=username)

print('\nGetting Detected Anomalies...\n')
nowUsecs = dateToUsecs(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
monthAgoUsecs = timeAgo(30, 'days')
alerts = api('get', 'alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=%s&maxAlerts=1000&startDateUsecs=%s&_includeTenantInfo=true' % (nowUsecs, monthAgoUsecs), mcm=True)
alerts = [a for a in alerts if a['alertType'] == 16011]
for alert in alerts:
    clusterName = [p['value'] for p in alert['propertyList'] if p['key'] == 'cluster'][0]
    jobName = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobName'][0]
    runUsecs = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobStartTimeUsecs'][0]
    objectName = [p['value'] for p in alert['propertyList'] if p['key'] == 'object'][0]
    sourceId = [p['value'] for p in alert['propertyList'] if p['key'] == 'entityId'][0]
    anomalyStrength = [p['value'] for p in alert['propertyList'] if p['key'] == 'anomalyStrength'][0]
    print(' Cluster: %s\n     Job: %s\n    Date: %s\n  Object: %s (%s)\nStrength: %s%%\n' % (clusterName, jobName, (usecsToDate(runUsecs)), objectName, sourceId, anomalyStrength))
