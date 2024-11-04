#!/usr/bin/env python
"""base V2 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)         # cluster to connect to
parser.add_argument('-u', '--username', type=str, required=True)    # username
parser.add_argument('-d', '--domain', type=str, default='local')    # (optional) domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')       # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)   # optional password
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-n', '--numruns', type=int, default=100)
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey
jobnames = args.jobname
joblist = args.joblist
numruns = args.numruns

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, noretry=True)

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))

# outfile
cluster = api('get', 'cluster')
dateString = now.strftime("%Y-%m-%d")
outfile = 'baseV2-%s-%s.csv' % (cluster['name'], dateString)
f = codecs.open(outfile, 'w')

# headings
f.write('Job Name,Tenant,Run Date,Status\n')


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

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true', v=2)

# catch invalid job names
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))
    exit(1)

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    if len(jobnames) == 0 or job['name'].lower() in [j.lower() for j in jobnames]:

        if len(job['permissions']) > 0 and 'name' in job['permissions'][0]:
            tenant = job['permissions'][0]['name']
            print('%s (%s)' % (job['name'], tenant))
        else:
            tenant = ''
            print('%s' % job['name'])

        endUsecs = nowUsecs
        while 1:
            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&endTimeUsecs=%s&includeTenants=true' % (job['id'], numruns, endUsecs), v=2)
            if len(runs['runs']) > 0:
                endUsecs = runs['runs'][-1]['localBackupInfo']['startTimeUsecs'] - 1
            else:
                break
            for run in runs['runs']:
                runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
                status = run['localBackupInfo']['status']
                print("    %s  %s" % (runStartTime, status))
                f.write('"%s","%s","%s","%s"\n' % (job['name'], tenant, runStartTime, status))

f.close()
print('\nOutput saved to %s\n' % outfile)
