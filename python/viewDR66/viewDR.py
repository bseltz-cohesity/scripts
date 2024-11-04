#!/usr/bin/env python
"""view failover"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

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
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--viewname', action='append', type=str)
parser.add_argument('-l', '--viewlist', type=str)
parser.add_argument('-if', '--initializefailover', action='store_true')
parser.add_argument('-ff', '--finalizefailover', action='store_true')
parser.add_argument('-uf', '--unplannedfailover', action='store_true')
parser.add_argument('-w', '--wait', action='store_true')

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
initializefailover = args.initializefailover
finalizefailover = args.finalizefailover
unplannedfailover = args.unplannedfailover
wait = args.wait


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

if initializefailover:
    action = 'Initiating pre-failover replication'
    params = {
        "type": "Planned",
        "plannedFailoverParams": {
            "type": "Prepare",
            "preparePlannedFailverParams": {
                "reverseReplication": False
            }
        }
    }
elif finalizefailover:
    action = 'Executing planned failover'
    params = {
        "type": "Planned",
        "plannedFailoverParams": {
            "type": "Finalize",
            "preparePlannedFailverParams": {}
        }
    }
elif unplannedfailover:
    action = 'Executing unplanned failover'
    params = {
        "type": "Unplanned",
        "unplannedFailoverParams": {
            "reverseReplication": False
        }
    }
else:
    print('No actions specified. Choose one of:\n    -fi, --initializefailover\n    -ff, --finalizefailover\n    -uf, --unplannedfailover\n')
    exit()

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

views = api('get', 'file-services/views', v=2)

migratedViewIds = []
migratedViews = {}
failoverIds = []

for viewname in viewnames:
    view = [v for v in views['views'] if v['name'].lower() == viewname.lower()]
    if view is None or len(view) == 0:
        print('view %s not found' % viewname)
    else:
        view = view[0]
        print('%s for %s' % (action, view['name']))
        result = api('post', 'data-protect/failover/views/%s' % view['viewId'], params, v=2)
        if result:
            failoverIds.append(result['id'])
            migratedViewIds.append(view['viewId'])
            migratedViews[view['viewId']] = view['name']

if wait:
    finishedStates = ['Succeeded', 'Failed']
    waiting = True
    while waiting is True:
        sleep(10)
        waiting = False
        for viewId in migratedViewIds:
            failover = api('get', 'data-protect/failover/views/%s' % viewId, v=2)
            if failover is not None and 'failovers' in failover and len(failover['failovers']) > 0:
                latestfailover = [f for f in failover['failovers'] if f['id'] in failoverIds]
                if latestfailover is not None and len(latestfailover) > 0:
                    latestfailover = latestfailover[0]
                    if latestfailover['status'] not in finishedStates:
                        waiting = True
                        print('View %s task is %s' % (migratedViews[viewId], latestfailover['status'].lower()))
                    else:
                        print('View %s task %s' % (migratedViews[viewId], latestfailover['status'].lower()))
                else:
                    waiting = True
            else:
                waiting = True
        if waiting is True:
            sleep(20)
