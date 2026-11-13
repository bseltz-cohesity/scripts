#!/usr/bin/env python
"""Exclude VMs from VMware Protection Groups (Cohesity v2 API)"""

# usage: ./excludeVMs.py -v mycluster -u myuser -d mydomain.net -j 'vm backup' -n mongodb
#        ./excludeVMs.py -v mycluster -u myuser -j 'vm backup' -xt -xp -vu vcuser -vp vcpassword

# import pyhesity wrapper module
from pyhesity import *
from pyVim import connect
import os
import re

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

if len(vmsToExclude) == 0 and vmmatch is None and len(excludeRules) == 0 and excludeTemplates is False and excludePoweredOff is False:
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

vCenterCache = {}      # vCenter id -> list of VMs
poweredOffCache = {}   # vCenter id -> set of ids of powered off VMs
exitCode = 0


def getVMs(vCenterId):
    """get VMs for a vCenter (cached)"""
    if vCenterId not in vCenterCache:
        vms = api('get', 'protectionSources/virtualMachines?vCenterId=%s' % vCenterId)
        if vms is None or isinstance(vms, (str, dict)):
            print("failed to get VMs for vCenter %s" % vCenterId)
            exit(1)
        vCenterCache[vCenterId] = vms
    return vCenterCache[vCenterId]


def getPoweredOff(vCenterId, vCenterName, vms):
    """get ids of powered off VMs for a vCenter (cached)"""
    if vCenterId not in poweredOffCache:
        vcenter = connect.ConnectNoSSL(vCenterName, 443, vcuser, vpassword)
        if not vcenter:
            print("Failed to connect to vcenter %s!" % vCenterName)
            exit(1)
        searcher = vcenter.content.searchIndex
        poweredOff = set()
        for vm in vms:
            uuid = vm.get('vmWareProtectionSource', {}).get('id', {}).get('uuid', None)
            if uuid is None:
                continue
            thisvm = searcher.FindByUuid(uuid=uuid, vmSearch=True, instanceUuid=True)
            if thisvm is None:
                thisvm = searcher.FindByUuid(uuid=uuid, vmSearch=True, instanceUuid=False)
            if thisvm is not None and thisvm.runtime.powerState == 'poweredOff':
                poweredOff.add(vm['id'])
        poweredOffCache[vCenterId] = poweredOff
    return poweredOffCache[vCenterId]


for job in jobs:
    if len(jobnamesLower) > 0 and job['name'].lower() not in jobnamesLower:
        continue

    vmwareParams = job.get('vmwareParams', None)
    if vmwareParams is None or vmwareParams.get('sourceId', None) is None:
        continue
    vCenterId = vmwareParams['sourceId']
    vms = getVMs(vCenterId)
    changed = False

    # build list of VMs (id -> (name, reason)) to act upon
    selected = {}

    # VMs selected by name (or list)
    for vmName in vmsToExclude:
        vm = [v for v in vms if v['name'].lower() == vmName.lower()]
        if not vm:
            print("VM %s not found!" % vmName)
        else:
            selected[vm[0]['id']] = (vm[0]['name'], 'name')

    for vm in vms:
        # VMs matching regex
        if vmmatch is not None and re.search(vmmatch, vm['name'], re.IGNORECASE):
            selected.setdefault(vm['id'], (vm['name'], 'match'))
        # VMs matching substring rules
        for excludeRule in excludeRules:
            if excludeRule.lower() in vm['name'].lower():
                selected.setdefault(vm['id'], (vm['name'], 'rule match'))
        # templates
        if excludeTemplates is True and vm.get('vmWareProtectionSource', {}).get('isVmTemplate', False) is True:
            selected.setdefault(vm['id'], (vm['name'], 'template'))

    # powered off VMs
    if excludePoweredOff is True:
        poweredOff = getPoweredOff(vCenterId, vmwareParams.get('sourceName', None) or str(vCenterId), vms)
        for vm in vms:
            if vm['id'] in poweredOff:
                selected.setdefault(vm['id'], (vm['name'], 'powered off'))

    # apply exclusions
    excludedIds = vmwareParams.get('excludeObjectIds', None)
    if excludedIds is None:
        excludedIds = []
    for vmId, (vmName, reason) in selected.items():
        if removeexclusion is True:
            if vmId in excludedIds:
                print("Removing exclusion for %s from %s (%s)" % (vmName, job['name'], reason))
                excludedIds = [i for i in excludedIds if i != vmId]
                changed = True
        else:
            if vmId not in excludedIds:
                print("Excluding %s from %s (%s)" % (vmName, job['name'], reason))
                excludedIds.append(vmId)
                changed = True
    vmwareParams['excludeObjectIds'] = excludedIds

    # update the job
    if changed is True:
        result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
        if failed(result):
            print("failed to update protection group %s" % job['name'])
            exitCode = 1

exit(exitCode)
