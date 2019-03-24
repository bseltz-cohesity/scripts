#!/usr/bin/env python
from oo_pyhesity import *

myCluster = CohesityCluster('mycluster', 'myuser', 'local')

print("\nProtection Jobs on {0}\n".format(myCluster.get('cluster')['name']))
for job in myCluster.get('protectionJobs'):
    print(job['name'])
