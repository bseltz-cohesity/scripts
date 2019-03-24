#!/usr/bin/env python
from pyhesity_oo import *

myCluster = CohesityCluster('bseltzve01', 'admin', 'local')
anotherCluster = CohesityCluster('10.99.1.64', 'admin', 'local')

print "\nProtection Jobs on {0}\n".format(myCluster.get('cluster')['name'])
for job in myCluster.get('protectionJobs'):
    print job['name']

print "\nProtection Jobs on {0}\n".format(anotherCluster.get('cluster')['name'])
for job in anotherCluster.get('protectionJobs'):
    print job['name']

