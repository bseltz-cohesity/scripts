#!/usr/bin/env python
"""Exclude VMs from VMware Protection Groups (Cohesity v2 API)"""

# usage: ./excludeVMs.py -v mycluster -u myuser -d mydomain.net -j 'vm backup' -n mongodb
#        ./excludeVMs.py -v mycluster -u myuser -j 'vm backup' -xt -xp -vu vcuser -vp vcpassword
#
# VMs selected by -mt, -x, -xt and -xp are only excluded if they are in scope of the
# protection group (selected by name, container or tag, and not already excluded).
# VMs named explicitly with -n or -l are always excluded.

# import pyhesity wrapper module
from pyhesity import *
from pyVim import connect
import os
import re
import ssl

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', action='append', type=str)         # protection group name(s) (default: all VMware groups)
parser.add_argument('-n', '--vmname', action='append', type=str)          # VM name(s) to exclude
parser.add_argument('-l', '--vmlist', type=str, default='')               # text file of VM names
parser.add_argument('-mt', '--vmmatch', type=str)                         # regex of VM names to exclude
parser.add_argument('-pm', '--prefixmatch', action='store_true')          # anchor vmmatch to start of name
parser.add_argument('-x', '--exclude', action='append', type=str)         # substring(s) of VM names to exclude
parser.add_argument('-xt', '--excludeTemplates', action='store_true')     # exclude VM templates
parser.add_argument('-xp', '--excludePoweredOff', action='store_true')    # exclude powered off VMs
parser.add_argument('-vu', '--vcenterUserName', type=str)                 # vCenter username (for -xp)
parser.add_argument('-vp', '--vcenterPassword', type=str)                 # vCenter password (for -xp)
parser.add_argument('-r', '--removeexclusion', action='store_true')       # remove exclusions instead of adding

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobnames = args.jobname or []
vmnames = args.vmname or []
vmlist = args.vmlist
vmmatch = args.vmmatch
prefixmatch = args.prefixmatch
excludeRules = args.exclude or []
excludeTemplates = args.excludeTemplates
excludePoweredOff = args.excludePoweredOff
vcuser = args.vcenterUserName
vpassword = args.vcenterPassword
removeexclusion = args.removeexclusion

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================

if excludePoweredOff is True:
    if vcuser is None or vpassword is None:
        print("vCenter UserName and Password required!")
        exit(1)


def failed(result):
    """test api result for failure"""
    return result is None or isinstance(result, str) or 'error' in result


# gather list of VM names to exclude
vmsToExclude = list(vmnames)
if vmlist != '':
    if os.path.isfile(vmlist):
        with open(vmlist, 'r') as f:
            vmsToExclude += [line.strip() for line in f.readlines() if line.strip() != '']
    else:
        print("VM list %s not found!" % vmlist)
        exit(1)

useRules = vmmatch is not None or len(excludeRules) > 0 or excludeTemplates is True or excludePoweredOff is True

if len(vmsToExclude) == 0 and useRules is False:
    print("No VMs to add")
    exit(0)

if vmmatch is not None and prefixmatch is True:
    vmmatch = '^%s' % vmmatch

# get the protection groups
jobs = []
paginationCookie = None
while True:
    uri = 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware&includeLastRunInfo=false'
    if paginationCookie is not None:
        uri = uri + '&paginationCookie=%s' % paginationCookie
    result = api('get', uri, v=2)
    if failed(result):
        print("failed to get protection groups")
        exit(1)
    jobs = jobs + (result.get('protectionGroups', None) or [])
    paginationCookie = result.get('paginationCookie', None)
    if paginationCookie is None:
        break

jobnamesLower = [j.lower() for j in jobnames]
for j in jobnames:
    if j.lower() not in [job['name'].lower() for job in jobs]:
        print("Job '%s' not found" % j)

hierarchyCache = {}        # vCenter id -> {'name': vCenter name, 'index': {object id: node}}
vCenterConnections = {}    # vCenter id -> vCenter search index
poweredOffCache = {}       # VM id -> True if powered off
exitCode = 0


# VM hierarchy and scope evaluation =====================================

def indexChildren(index, source, parents=None):
    """index a protection source and its children, tracking all ancestors (containers and tags)"""
    parents = set(parents or [])
    protectionSource = source['protectionSource']
    envSource = protectionSource.get('vmWareProtectionSource', None) or {}
    # tag nodes add their tag id to the parents of their children
    tagAttributes = envSource.get('tagAttributes', None) or []
    if isinstance(tagAttributes, dict):
        tagAttributes = [tagAttributes]
    for tagAttribute in tagAttributes:
        if tagAttribute.get('id', None) is not None:
            parents.add(tagAttribute['id'])
    node = index.get(protectionSource['id'], None)
    if node is None:
        node = {
            'id': protectionSource['id'],
            'name': protectionSource['name'],
            'type': envSource.get('type', None),
            'parents': set(parents),
            'indexed': False,
            'source': envSource
        }
        index[protectionSource['id']] = node
    node['parents'] |= parents
    children = source.get('nodes', None) or []
    if len(children) > 0 and node['indexed'] is False:
        node['indexed'] = True
        childParents = node['parents'] | set([protectionSource['id']])
        for child in children:
            indexChildren(index, child, childParents)


def getHierarchy(vCenterId):
    """get (and cache) the hierarchy of a vCenter"""
    if vCenterId not in hierarchyCache:
        result = api('get', 'protectionSources?id=%s&includeVMFolders=true' % vCenterId)
        if failed(result):
            print("failed to get hierarchy for vCenter %s" % vCenterId)
            exit(1)
        roots = result if isinstance(result, list) else [result]
        index = {}
        vCenterName = None
        for root in roots:
            if vCenterName is None and root['protectionSource']['id'] == vCenterId:
                vCenterName = root['protectionSource']['name']
            indexChildren(index, root)
        hierarchyCache[vCenterId] = {'name': vCenterName, 'index': index}
    return hierarchyCache[vCenterId]


def getChildren(index, objectId):
    """get VMs that are, or are under, an object (container, tag or VM)"""
    return [n for n in index.values() if n['type'] == 'kVirtualMachine' and (objectId in n['parents'] or objectId == n['id'])]


def getTaggedVMs(index, tagIds):
    """get VMs that have all of the specified tags"""
    matchIds = None
    for tagId in tagIds:
        tagVMIds = set([n['id'] for n in getChildren(index, tagId)])
        matchIds = tagVMIds if matchIds is None else matchIds & tagVMIds
    return [index[i] for i in (matchIds or [])]


def getScope(index, vmwareParams):
    """get VMs that are in scope of a protection group (selected, and not excluded)"""
    selected = {}
    directIds = set([o['id'] for o in vmwareParams.get('objects', None) or []])
    # explicit and container selections
    for protectedObject in vmwareParams.get('objects', None) or []:
        for vm in getChildren(index, protectedObject['id']):
            selected[vm['id']] = vm
    # tag selections
    for tagIds in vmwareParams.get('vmTagIds', None) or []:
        for vm in getTaggedVMs(index, tagIds):
            selected[vm['id']] = vm
    # explicit and container exclusions
    for excludedId in vmwareParams.get('excludeObjectIds', None) or []:
        for vm in getChildren(index, excludedId):
            # excluding a VM that is manually selected has no effect (it must be removed from the selections)
            if vm['id'] == excludedId and excludedId in directIds:
                continue
            selected.pop(vm['id'], None)
    # tag exclusions
    for tagIds in vmwareParams.get('excludeVmTagIds', None) or []:
        for vm in getTaggedVMs(index, tagIds):
            selected.pop(vm['id'], None)
    return selected


# vCenter power state ===================================================

def getPoweredOff(vCenterId, vCenterName, vms):
    """get ids of powered off VMs from a list of VMs (cached)"""
    if vCenterId not in vCenterConnections:
        # Disable SSL certificate verification
        sslContext = ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)
        sslContext.check_hostname = False
        sslContext.verify_mode = ssl.CERT_NONE

        vcenter = connect.SmartConnect(host=vCenterName,
                                       user=vcuser,
                                       pwd=vpassword,
                                       sslContext=sslContext)
        if not vcenter:
            print("\nFailed to connect to vcenter!")
            exit(1)

        vCenterConnections[vCenterId] = vcenter.content.searchIndex
    searcher = vCenterConnections[vCenterId]
    poweredOff = set()
    for vm in vms:
        if vm['id'] not in poweredOffCache:
            poweredOffCache[vm['id']] = False
            uuid = (vm['source'].get('id', None) or {}).get('uuid', None)
            if uuid is not None:
                thisvm = searcher.FindByUuid(uuid=uuid, vmSearch=True, instanceUuid=True)
                if thisvm is None:
                    thisvm = searcher.FindByUuid(uuid=uuid, vmSearch=True, instanceUuid=False)
                if thisvm is not None and thisvm.runtime.powerState == 'poweredOff':
                    poweredOffCache[vm['id']] = True
        if poweredOffCache[vm['id']] is True:
            poweredOff.add(vm['id'])
    return poweredOff


# process protection groups =============================================

for job in jobs:
    if len(jobnamesLower) > 0 and job['name'].lower() not in jobnamesLower:
        continue

    vmwareParams = job.get('vmwareParams', None)
    if vmwareParams is None or vmwareParams.get('sourceId', None) is None:
        continue
    vCenterId = vmwareParams['sourceId']
    hierarchy = getHierarchy(vCenterId)
    index = hierarchy['index']
    allVMs = [n for n in index.values() if n['type'] == 'kVirtualMachine']
    excludedIds = list(vmwareParams.get('excludeObjectIds', None) or [])
    changed = False

    # build list of VMs (id -> (name, reason)) to act upon
    selected = {}

    # VMs selected by name (or list) - not subject to scope evaluation
    for vmName in vmsToExclude:
        matches = [v for v in allVMs if v['name'].lower() == vmName.lower()]
        if not matches:
            print("VM %s not found!" % vmName)
        for vm in matches:
            selected[vm['id']] = (vm['name'], 'name')

    # VMs selected by rules - only VMs in scope of the group
    if useRules is True:
        if removeexclusion is True:
            # when removing, consider VMs that are currently excluded
            candidates = [index[i] for i in excludedIds if i in index and index[i]['type'] == 'kVirtualMachine']
        else:
            candidates = list(getScope(index, vmwareParams).values())
        candidates = sorted(candidates, key=lambda v: v['name'].lower())

        # vCenter reports templates as powered off, so templates are only
        # considered for the powered off check if -xt was also specified
        poweredOffCandidates = [v for v in candidates if excludeTemplates is True or v['source'].get('isVmTemplate', False) is not True]
        poweredOff = set()
        if excludePoweredOff is True and len(poweredOffCandidates) > 0:
            vCenterName = vmwareParams.get('sourceName', None) or hierarchy['name'] or str(vCenterId)
            poweredOff = getPoweredOff(vCenterId, vCenterName, poweredOffCandidates)

        for vm in candidates:
            # VMs matching regex
            if vmmatch is not None and re.search(vmmatch, vm['name'], re.IGNORECASE):
                selected.setdefault(vm['id'], (vm['name'], 'match'))
            # VMs matching substring rules
            for excludeRule in excludeRules:
                if excludeRule.lower() in vm['name'].lower():
                    selected.setdefault(vm['id'], (vm['name'], 'rule match'))
            # templates
            if excludeTemplates is True and vm['source'].get('isVmTemplate', False) is True:
                selected.setdefault(vm['id'], (vm['name'], 'template'))
            # powered off VMs
            if vm['id'] in poweredOff:
                selected.setdefault(vm['id'], (vm['name'], 'powered off'))

    # apply exclusions
    for vmId, (vmName, reason) in selected.items():
        if removeexclusion is True:
            if vmId in excludedIds:
                print("Removing exclusion for %s from %s (%s)" % (vmName, job['name'], reason))
                excludedIds = [i for i in excludedIds if i != vmId]
                changed = True
        elif vmId in [o['id'] for o in vmwareParams.get('objects', None) or []]:
            # VM is manually selected: remove it from the group's selections
            remaining = [o for o in vmwareParams['objects'] if o['id'] != vmId]
            if len(remaining) == 0 and len(vmwareParams.get('vmTagIds', None) or []) == 0:
                print("Cannot remove %s from %s (%s): it is the only selection in the group" % (vmName, job['name'], reason))
                continue
            print("Removing %s from %s selections (%s)" % (vmName, job['name'], reason))
            vmwareParams['objects'] = remaining
            changed = True
            # if the VM is still selected by a container or tag, exclude it as well
            if vmId in getScope(index, dict(vmwareParams, excludeObjectIds=excludedIds)):
                print("Excluding %s from %s (%s)" % (vmName, job['name'], reason))
                excludedIds.append(vmId)
        else:
            if vmId not in excludedIds:
                print("Excluding %s from %s (%s)" % (vmName, job['name'], reason))
                excludedIds.append(vmId)
                changed = True

    # update the job
    if changed is True:
        vmwareParams['excludeObjectIds'] = excludedIds
        result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
        if failed(result):
            print("failed to update protection group %s" % job['name'])
            exitCode = 1

exit(exitCode)