import pandas as pd
from pyhesity import *

apiKey = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

apiauth(vip='helios.cohesity.com', username='helios', domain='local', useApiKey=True, password=apiKey, quiet=True)

nowUsecs = timeAgo(0, 'days')
monthAgoUsecs = timeAgo(31, 'days')

alerts = api('get', 'alerts?alertCategoryList=kSecurity&alertStateList=kOpen&endDateUsecs=%s&maxAlerts=1000&startDateUsecs=%s&_includeTenantInfo=true' % (nowUsecs, monthAgoUsecs), mcm=True)
alerts = [a for a in alerts if a['alertType'] == 16011]

data = []

for alert in alerts:
    clusterName = [p['value'] for p in alert['propertyList'] if p['key'] == 'cluster'][0]
    jobName = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobName'][0]
    runUsecs = [p['value'] for p in alert['propertyList'] if p['key'] == 'jobStartTimeUsecs'][0]
    objectName = [p['value'] for p in alert['propertyList'] if p['key'] == 'object'][0]
    objectType = [p['value'] for p in alert['propertyList'] if p['key'] == 'environment'][0][1:]
    anomalyStrength = [p['value'] for p in alert['propertyList'] if p['key'] == 'anomalyStrength'][0]
    data.append([clusterName, jobName, (usecsToDate(runUsecs)), objectName, objectType, anomalyStrength])
df = pd.DataFrame(sorted(data, key=lambda d: d[0].lower()), columns=['ClusterName', 'JobName', 'Date', 'ObjectName', 'ObjectType', 'Strength'])
print(df)
