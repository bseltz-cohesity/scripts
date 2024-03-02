#!/usr/bin/env python

from pyhesity import *
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
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-jl', '--joblist', type=str)
parser.add_argument('-f', '--filter', action='append', type=str)
parser.add_argument('-fl', '--filterlist', type=str)
parser.add_argument('-r', '--regex', action='append', type=str)
parser.add_argument('-rl', '--regexlist', type=str)
parser.add_argument('-clear', '--clear', action='store_true')
parser.add_argument('-remove', '--remove', action='store_true')

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
jobnames = args.jobname
joblist = args.joblist
filters = args.filter
filterlist = args.filterlist
regexes = args.regex
regexlist = args.regexlist
clear = args.clear
remove = args.remove


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


jobnames = gatherList(jobnames, joblist, name='jobs', required=False)
filters = gatherList(filters, filterlist, name='filters', required=False)
regexes = gatherList(regexes, regexlist, name='regexes', required=False)

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

jobnames = gatherList(jobnames, joblist, name='jobs', required=False)

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&environments=kSQL', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

if jobs['protectionGroups'] is None:
    print('no jobs found')
    exit()

paramName = {
    "kVolume": "volumeProtectionTypeParams",
    "kNative": "nativeProtectionTypeParams",
    "kFile": "fileProtectionTypeParams"
}

newExclusions = False
if len(filters) > 0 or len(regexes) > 0:
    newExclusions = True

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        print('%s' % job['name'])
        params = job['mssqlParams'][paramName[job['mssqlParams']['protectionType']]]
        if clear is True:
            if 'excludeFilters' in params:
                del params['excludeFilters']
        if newExclusions is True:
            if 'excludeFilters' not in params or params['excludeFilters'] is None:
                params['excludeFilters'] = []
            for filterItem in filters:
                if remove is True:
                    if params['excludeFilters'] is not None and len(params['excludeFilters']) > 0:
                        params['excludeFilters'] = [f for f in params['excludeFilters'] if f['filterString'].lower() != filterItem.lower() and f['isRegularExpression'] is False]
                else:
                    existingFilter = None
                    if params['excludeFilters'] is not None and len(params['excludeFilters']) > 0:
                        existingFilter = [f for f in params['excludeFilters'] if f['filterString'].lower() == filterItem.lower() and f['isRegularExpression'] is False]
                    if existingFilter is None or len(existingFilter) == 0:
                        params['excludeFilters'].append({
                            "filterString": filterItem,
                            "isRegularExpression": False
                        })
            for filterItem in regexes:
                if remove is True:
                    if params['excludeFilters'] is not None and len(params['excludeFilters']) > 0:
                        params['excludeFilters'] = [f for f in params['excludeFilters'] if f['filterString'].lower() != filterItem.lower() and f['isRegularExpression'] is True]
                else:
                    existingFilter = None
                    if params['excludeFilters'] is not None and len(params['excludeFilters']) > 0:
                        existingFilter = [f for f in params['excludeFilters'] if f['filterString'].lower() == filterItem.lower() and f['isRegularExpression'] is True]
                    if existingFilter is None or len(existingFilter) == 0:
                        params['excludeFilters'].append({
                            "filterString": filterItem,
                            "isRegularExpression": True
                        })
        if 'excludeFilters' in params and params['excludeFilters'] is not None and len(params['excludeFilters']) > 0:
            for f in params['excludeFilters']:
                isRegex = 'FILTER'
                if f['isRegularExpression'] is True:
                    isRegex = ' REGEX'
                print('  %s: %s' % (isRegex, f['filterString']))
        if clear is True or newExclusions is True:
            if 'excludeFilters' in params and (params['excludeFilters'] is None or len(params['excludeFilters']) == 0):
                del params['excludeFilters']
            response = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
