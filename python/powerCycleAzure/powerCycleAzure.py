#!/usr/bin/env python
"""Power on/off an Azure Cloud Edition cluster"""

### usage: ./powerCycleAzure.py -s 10.0.1.6 \
#                     -u admin \
#                     -o poweroff \
#                     -n BSeltz-AzureCE-1 \
#                     -n BSeltz-AzureCE-2 \
#                     -n BSeltz-AzureCE-3 \
#                     -k xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
#                     -t xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
#                     -b xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
#                     -r resgroup1

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.compute import ComputeManagementClient

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-o', '--operation', choices=['poweron', 'poweroff'], required=True)
parser.add_argument('-n', '--node', action='append', type=str, required=True)
parser.add_argument('-b', '--subscription', type=str, required=True)
parser.add_argument('-k', '--accesskey', type=str, required=True)
parser.add_argument('-t', '--tenant', type=str, required=True)
parser.add_argument('-r', '--resourcegroup', type=str, required=True)

args = parser.parse_args()

vip = args.server
username = args.username
domain = args.domain
operation = args.operation
nodes = list(args.node)


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


def stop_cluster():
    print('Connecting to Cohesity...')
    apiauth(vip, username, domain, quiet=True)
    if(apiconnected() is True):
        stat = api('get', '/nexus/cluster/status')
        clusterId = stat['clusterId']
        stopping = api('post', '/nexus/cluster/stop', {"clusterId": clusterId})
        print(stopping['message'])
        wait_for_sync(False)
        print('Cluster stopped successfully!')
    else:
        print('Unable to connect to cluster!')
        exit(1)


def start_cluster():
    print('Connecting to Cohesity...')
    started = False
    while started is False:
        apiauth(vip, username, domain, quiet=True)
        if(apiconnected() is True):
            stat = api('get', '/nexus/cluster/status')
            clusterId = stat['clusterId']
            starting = api('post', '/nexus/cluster/start', {"clusterId": clusterId})
            print(starting['message'])
            wait_for_sync(True)
            print('Cluster started successfully!')
            started = True


def powerOff():
    print('Stopping cloud edition instances...')
    for node in nodes:
        async_vm_stop = compute_client.virtual_machines.power_off(args.resourcegroup, node)


def powerOn():
    print('Starting cloud edition instances...')
    for node in nodes:
        async_vm_start = compute_client.virtual_machines.start(args.resourcegroup, node)


### connect to Azure
try:
    print('Connecting to azure...')
    credentials = ServicePrincipalCredentials(
        client_id=args.accesskey,
        secret=pw('azure', args.accesskey),
        tenant=args.tenant
    )
    subscription_id = args.subscription
    compute_client = ComputeManagementClient(credentials, subscription_id)
except Exception as e:
    print('Unable to connect to azure!')
    print(str(e))
    exit(1)

if(operation == 'poweroff'):
    stop_cluster()
    powerOff()
else:
    powerOn()
    start_cluster()
