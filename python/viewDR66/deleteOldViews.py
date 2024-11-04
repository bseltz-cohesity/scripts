#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--viewname', action='append', type=str)
parser.add_argument('-l', '--viewlist', type=str, default=None)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
viewnames = args.viewname
viewlist = args.viewlist


# gather list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


viewnames = gatherList(viewnames, viewlist, name='views', required=True)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode)

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

jobs = api('get', 'data-protect/protection-groups?isActive=true&isPaused=true&environments=kView', v=2)
views = api('get', 'file-services/views', v=2)

# delete old remote views from target cluster
for viewname in viewnames:
    view = [v for v in views['views'] if v['name'].lower() == viewname.lower()]
    if view is None or len(view) == 0:
        print('view %s not found' % viewname)
    else:
        view = view[0]
        if view['isReadOnly'] is not True:
            print('View %s is live. Skipping...' % view['name'])
        else:
            print('Deleting old remote view %s' % view['name'])
            result = api('delete', 'views/%s' % view['name'])

if 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
    for job in jobs['protectionGroups']:
        if job['viewParams']['objects'] is None or len(job['viewParams']['objects']) == 0:
            print('Deleting old job %s' % job['name'])
            result = api('delete', 'data-protect/protection-groups/%s' % job['id'], v=2)
