#!/usr/bin/env python
"""Protect Netapp C-mode Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-s', '--sourcename', action='append', type=str)
parser.add_argument('-l', '--sourcelist', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-x', '--excludelist', type=str)
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-f', '--joblist', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
sourcenames = args.sourcename
sourcelist = args.sourcelist
excludes = args.exclude
excludelist = args.excludelist
jobnames = args.jobname
joblist = args.joblist

# read exclude file
if excludes is None:
    excludes = []
if excludelist is not None:
    f = open(excludelist, 'r')
    excludes += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# read jobs file
if jobnames is None:
    jobnames = []
if joblist is not None:
    f = open(joblist, 'r')
    jobnames += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# read sources file
if sourcenames is None:
    sourcenames = []
if sourcelist is not None:
    f = open(sourcelist, 'r')
    sourcenames += [e.strip() for e in f.readlines() if e.strip() != '']
    f.close()

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt))

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# get registered Netapp sources
sources = api('get', 'protectionSources?environments=kNetapp')
if sourcenames is not None and len(sourcenames) > 0:
    sources = [s for s in sources if s['protectionSource']['name'].lower() in [n.lower() for n in sourcenames]]

sourceids = []
for source in sources:
    # netapp source id
    sourceids.append(source['protectionSource']['id'])
    for node in source['nodes']:
        # svm source id
        sourceids.append(node['protectionSource']['id'])

protectionGroups = api('get', 'data-protect/protection-groups?environments=kNetapp&isDeleted=false&isActive=true', v=2)
jobs = [p for p in protectionGroups['protectionGroups'] if p['netappParams']['sourceId'] in sourceids]
if len(jobnames) > 0:
    jobs = [j for j in jobs if j['name'].lower() in [jn.lower() for jn in jobnames]]

for job in jobs:
    madechanges = False
    for obj in job['netappParams']['objects']:
        objectid = obj['id']
        for source in sources:
            thissource = False
            if source['protectionSource']['id'] == objectid:
                thissource = True
            for svm in source['nodes']:
                thissvm = False
                if svm['protectionSource']['id'] == objectid:
                    thissvm = True
                if thissource is True or thissvm is True:
                    for volume in svm['nodes']:
                        for excluderule in excludes:
                            if excluderule.lower() in volume['protectionSource']['name'].lower():
                                volumeid = volume['protectionSource']['id']
                                if job['netappParams']['excludeObjectIds'] is None:
                                    job['netappParams']['excludeObjectIds'] = []
                                if volumeid not in job['netappParams']['excludeObjectIds']:
                                    print('excluding %s from %s' % (volume['protectionSource']['name'], job['name']))
                                    job['netappParams']['excludeObjectIds'].append(volumeid)
                                    madechanges = True
    if madechanges is True:
        pass
        result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
