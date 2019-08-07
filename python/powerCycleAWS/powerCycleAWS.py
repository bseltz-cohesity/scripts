#!/usr/bin/env python
"""Power on/off an AWS Cloud Edition cluster"""

### usage: ./powerCycleAWS.py -s 172.31.28.144 -u admin -o poweroff -n i-00b359f39aa83551d -n i-0aa0725c31c208d63 -n i-0fcc7118fb230b47e -k XXXXXXXXXXXXXXXXXXXX -r us-east-2

### import pyhesity wrapper module
from pyhesity import *
from time import sleep
import boto3

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-o', '--operation', choices=['poweron', 'poweroff'], required=True)
parser.add_argument('-n', '--node', action='append', type=str, required=True)
parser.add_argument('-k', '--aws_access_key_id', type=str, required=True)
parser.add_argument('-r', '--region', type=str, required=True)

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
    ec2.instances.filter(InstanceIds=nodes).stop()


def powerOn():
    print('Starting cloud edition instances...')
    ec2.instances.filter(InstanceIds=nodes).start()


### connect to ec2
try:
    print('Connecting to ec2...')
    ec2 = boto3.resource(service_name='ec2', region_name=args.region, aws_access_key_id=args.aws_access_key_id, aws_secret_access_key=pw(vip='ec2', username=args.aws_access_key_id))
except Exception:
    print('Unable to connect to ec2!')
    exit(1)


if(operation == 'poweroff'):
    stop_cluster()
    powerOff()
else:
    powerOn()
    start_cluster()
