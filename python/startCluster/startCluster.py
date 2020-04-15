#!/usr/bin/env python
"""start Cohesity cluster"""

### import pyhesity wrapper module
from pyhesity import *
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain


def wait_for_sync(starting=False):
    if(starting is True):
        print('Waiting for cluster to start...')
    else:
        print('Waiting for cluster to stop...')

    synced = False
    correctState = False

    while synced is False or correctState is False:
        sleep(5)
        apiauth(vip, username, domain, quiet=True)
        if(apiconnected() is True):
            stat = api('get', '/nexus/cluster/status', quiet=True)
            if stat is not None:
                if stat['isServiceStateSynced'] is True:
                    synced = True
                if stat['bulletinState']['runAllServices'] == starting:
                    correctState = True


print('Connecting to Cohesity...')
apiauth(vip, username, domain, quiet=True)
stat = api('get', '/nexus/cluster/status')
clusterId = stat['clusterId']
starting = api('post', '/nexus/cluster/start', {"clusterId": clusterId})
print(starting['message'])
wait_for_sync(True)
print('Cluster started successfully!')
