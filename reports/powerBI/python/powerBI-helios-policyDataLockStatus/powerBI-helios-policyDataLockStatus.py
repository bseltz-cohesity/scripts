import pandas as pd
from pyhesity import *

apiKey = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

apiauth(vip='helios.cohesity.com', username='helios', domain='local', useApiKey=True, password=apiKey, quiet=True)

data = []

for hcluster in heliosClusters():
    heliosCluster(hcluster['name'])
    policies = api('get', 'protectionPolicies')
    if policies is not None:
        for policy in policies:
            dataLock = False
            if 'wormRetentionType' in policy and policy['wormRetentionType'] == 'kCompliance':
                dataLock = True
            data.append([hcluster['name'], policy['name'], dataLock])

df = pd.DataFrame(data, columns=['ClusterName', 'PolicyName', 'DataLock'])
print(df)
