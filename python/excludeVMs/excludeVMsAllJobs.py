#!/usr/bin/env python
"""Apply Exclusion Rules to VM Autoprotect Protection Job"""

# usage: ./excludeVMs.py -v mycluster -u myuser [-d mydomain.net -j 'VM Backup' -xt -x sql -x ora

# import pyhesity wrapper module
from pyhesity import *
from pyVim import connect

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-x', '--exclude', action='append', type=str)
parser.add_argument('-xt', '--excludeTemplates', action='store_true')
parser.add_argument('-xp', '--excludePoweredOff', action='store_true')
parser.add_argument('-vu', '--vcenterUserName', type=str)
parser.add_argument('-vp', '--vcenterPassword', type=str)

args = parser.parse_args()

vip = args.vip                 # cluster name/ip
username = args.username       # username to connect to cluster
domain = args.domain           # domain of username (e.g. local, or AD domain)
excludeTemplates = args.excludeTemplates  # boolean exclude templates or not
excludeRules = args.exclude    # list of substrings to exclude
excludePoweredOff = args.excludePoweredOff  # boolean exclude powered off VMs
vcuser = args.vcenterUserName  # vCenter username
vpassword = args.vcenterPassword  # vCenter password

if excludeRules is None:
    excludeRules = []

if excludePoweredOff is True:
    if vcuser is None or vpassword is None:
        print("vCenter UserName and Password required!")
        exit(1)

# functions =============================================


def getnodes(obj, parentid=0):
    """gather list of VMs and parent/child relationships"""
    global nodes
    global nodeParents
    nodes.append(obj)
    if parentid not in nodeParents.keys():
        nodeParents[parentid] = []
    if obj['protectionSource']['id'] not in nodeParents.keys():
        nodeParents[obj['protectionSource']['id']] = nodeParents[parentid] + [parentid]
    else:
        nodeParents[obj['protectionSource']['id']] = list(set(nodeParents[parentid] + [parentid] + nodeParents[obj['protectionSource']['id']]))
    if 'nodes' in obj:
        for node in obj['nodes']:
            getnodes(node, obj['protectionSource']['id'])


def exclude(node, job, reason):
    """add exclusions to protection job"""
    if 'excludeSourceIds' not in job:
        job['excludeSourceIds'] = []
    if node['protectionSource']['id'] not in job['excludeSourceIds']:
        job['excludeSourceIds'].append(node['protectionSource']['id'])
        print("   adding %s to exclusions (%s)" % (node['protectionSource']['name'], reason))


# end functions =========================================

# authenticate
apiauth(vip, username, domain)

clusterid = api('get', 'cluster')['id']

for job in api('get', 'protectionJobs'):
    origclusterid = int(job['policyId'].split(':')[0])

    if job['environment'] == 'kVMware' and origclusterid == clusterid:
        print("looking for exclusions in job: %s..." % job['name'])

        parentId = job['parentSourceId']

        # get source info (vCenter)
        parentSource = api('get', 'protectionSources?allUnderHierarchy=true&excludeTypes=kResourcePool&id=%s&includeEntityPermissionInfo=true&includeVMFolders=true' % parentId)[0]

        if excludePoweredOff is True:
            vcentername = parentSource['protectionSource']['vmWareProtectionSource']['name']
            vcenter = connect.ConnectNoSSL(vcentername, 443, vcuser, vpassword)
            if vcenter:
                searcher = vcenter.content.searchIndex
            else:
                print("Failed to connect to vcenter!")
                exit(1)

        # gather list of VMs and parent/child relationships
        nodes = []
        parents = []
        nodeParents = {}
        getnodes(parentSource)

        # apply VM exclusion rules
        for sourceId in job['sourceIds']:
            for node in nodes:

                # if vm (node) is a child of the container (sourceId)
                if sourceId in nodeParents[node['protectionSource']['id']]:

                    # if vm is a template
                    if excludeTemplates is True and 'isVmTemplate' in node['protectionSource']['vmWareProtectionSource']:
                        if node['protectionSource']['vmWareProtectionSource']['isVmTemplate'] is True:
                            exclude(node, job, 'template')

                    # if vm name matches an exclusion rule
                    for excludeRule in excludeRules:
                        if excludeRule.lower() in node['protectionSource']['name'].lower():
                            exclude(node, job, 'rule match')

                    # if vm is powered off
                    if excludePoweredOff is True:
                        if 'uuid' in node['protectionSource']['vmWareProtectionSource']['id']:
                            vm = searcher.FindByUuid(uuid=node['protectionSource']['vmWareProtectionSource']['id']['uuid'], vmSearch=True, instanceUuid=True)
                            if vm is not None and vm.runtime.powerState == 'poweredOff':
                                exclude(node, job, 'powered off')

        # update job with new exclusions
        updatedJob = api('put', 'protectionJobs/%s' % job['id'], job)
