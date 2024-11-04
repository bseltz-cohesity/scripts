#!/usr/bin/env python
"""base V2 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-c', '--commit', action='store_true')
parser.add_argument('-s', '--skiphostwithexcludes', action='store_true')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
jobnames = args.jobname
joblist = args.joblist
commit = args.commit
skiphostwithexcludes = args.skiphostwithexcludes

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

print()

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'updateWindowsAllDrives-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('"Job Name","Tenant","ObjectName","IncludePath","ExcludePaths"\n')


# gather server list
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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kPhysical', v=2)

if jobs['protectionGroups'] is None:
    print('no physical jobs found')
    exit()

jobs['protectionGroups'] = [p for p in jobs['protectionGroups'] if p['physicalParams']['protectionType'] == 'kFile']

if jobs['protectionGroups'] is None:
    print('no physical file-based jobs found')
    exit()

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

jobsToUpdate = []

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:
        updateJob = False
        if len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
            tenant = job['permissions'][0]['name']
            print('%s (%s)' % (job['name'], tenant))
            impersonate(tenant)
        else:
            tenant = ''
            print('%s' % job['name'])
            switchback()

        for object in job['physicalParams']['fileProtectionTypeParams']['objects']:
            updateObject = False
            source = api('get', 'protectionSources/objects/%s' % object['id'])
            sourceType = None            
            try:
                sourceType = source['physicalProtectionSource']['hostType']
            except Exception:
                pass
            if sourceType == 'kWindows':
                includedPaths = [f['includedPath'].lower() for f in object['filePaths']]
                if len(includedPaths) == 1 and includedPaths[0] == '/c/' and (object['filePaths'][0]['excludedPaths'] is None or skiphostwithexcludes is False):
                    excludedPaths = ''
                    if object['filePaths'][0]['excludedPaths'] is not None:
                        excludedPaths = '; '.join(object['filePaths'][0]['excludedPaths'])
                    updateObject = True
                    if commit is True:
                        print('    updating %s' % object['name'])
                    else:
                        print('    %s' % object['name'])
                    object['filePaths'][0]['includedPath'] = '$ALL_LOCAL_DRIVES'
                    updateJob = True
                    f.write('"%s","%s","%s","%s","%s"\n' % (job['name'], tenant, object['name'], includedPaths[0], excludedPaths))
        if updateJob is True:
            jobsToUpdate.append(job['name'])
        if updateJob is True and commit is True:
            result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

if commit is not True and len(jobsToUpdate) > 0:
    jobsToUpdate = list(set(jobsToUpdate))
    print('\nThe following jobs have only C: protected:\n')
    print('    %s' % '\n    '.join(jobsToUpdate))

f.close()
print('\nOutput saved to %s\n' % outfile)
