#!/usr/bin/env python
"""update protection group settings"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

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
parser.add_argument('-n', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-j', '--jobname', action='append', type=str)
parser.add_argument('-l', '--joblist', type=str)
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-np', '--newpolicyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default=None)
parser.add_argument('-st', '--starttime', type=str, default=None)
parser.add_argument('-is', '--incrementalsla', type=int, default=None)
parser.add_argument('-fs', '--fullsla', type=int, default=None)
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-r', '--resume', action='store_true')
parser.add_argument('-q', '--noquiesce', action='store_true')

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
jobnames = args.jobname
joblist = args.joblist
policyname = args.policyname
newpolicyname = args.newpolicyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
pause = args.pause
resume = args.resume
noquiesce = args.noquiesce

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

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

now = datetime.now()

# outfile
cluster = api('get', 'cluster')
outfile = 'log-updateProtectionGroup-%s.txt' % cluster['name']
f = codecs.open(outfile, 'w')


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

# enforce filtering
if len(jobnames) == 0 and policyname is None and newpolicyname is not None:
    print('Must specify --policyname or --jobname or --joblist\n')
    exit()

# require change
if newpolicyname is None and starttime is None and timezone is None and incrementalsla is None and fullsla is None and pause is not True and resume is not True and noquiesce is not True:
    print('No changes requested\n')
    exit()

jobs = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
policies = api('get', 'data-protect/policies', v=2)
if newpolicyname is not None:
    newpolicy = [p for p in policies['policies'] if p['name'].lower() == newpolicyname.lower()]
    if newpolicy is None or len(newpolicy) == 0:
        print('Policy %s not found\n' % newpolicyname)
        exit(1)
    else:
        newpolicyid = newpolicy[0]['id']

# filter jobs on old policy name
if policyname is not None:
    oldpolicy = [p for p in policies['policies'] if p['name'].lower() == policyname.lower()]
    if oldpolicy is not None and len(oldpolicy) > 0:
        oldpolicyid = oldpolicy[0]['id']
        jobs['protectionGroups'] = [p for p in jobs['protectionGroups'] if p['policyId'] == oldpolicyid]

# filter jobs on jobnames list
if len(jobnames) > 0:
    jobs['protectionGroups'] = [p for p in jobs['protectionGroups'] if p['name'].lower() in [n.lower() for n in jobnames]]

# report jobs not found
notfoundjobs = [n for n in jobnames if n.lower() not in [j['name'].lower() for j in jobs['protectionGroups']]]
if len(notfoundjobs) > 0:
    print('Jobs not found: %s' % ', '.join(notfoundjobs))

if jobs['protectionGroups'] is None or len(jobs['protectionGroups']) == 0:
    print('No jobs found\n')
    exit(1)

if starttime is not None:
    # parse starttime
    try:
        (hour, minute) = starttime.split(':')
        hour = int(hour)
        minute = int(minute)
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            print('starttime is invalid!')
            exit(1)
    except Exception:
        print('starttime is invalid!')
        exit(1)

for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
    changedJob = False
    print('%s' % job['name'])
    f.write('%s\n' % job['name'])
    if newpolicyname is not None:
        job['policyId'] = newpolicyid
        changedJob = True
        print('    changed policy to %s' % newpolicyname)
        f.write('    changed policy to %s\n' % newpolicyname)
    if starttime is not None:
        job['startTime']['hour'] = int(hour)
        job['startTime']['minute'] = int(minute)
        changedJob = True
        print('    changed startTime to %s' % starttime)
        f.write('    changed startTime to %s\n' % starttime)
    if timezone is not None:
        job['startTime']['timeZone'] = timezone
        changedJob = True
        print('    changed timeZone to %s' % timezone)
        f.write('    changed timeZone to %s\n' % timezone)
    for sla in job['sla']:
        if sla['backupRunType'] == 'kIncremental' and incrementalsla is not None:
            sla['slaMinutes'] = incrementalsla
            changedJob = True
            print('    changed incremental SLA to %s' % incrementalsla)
            f.write('    changed incremental SLA to %s\n' % incrementalsla)
        if sla['backupRunType'] == 'kFull' and fullsla is not None:
            sla['slaMinutes'] = fullsla
            changedJob = True
            print('    changed full SLA to %s' % fullsla)
            f.write('    changed full SLA to %s\n' % fullsla)
    if pause is True:
        job['isPaused'] = True
        changedJob = True
        print('    paused')
        f.write('    paused\n')
    if resume is True:
        job['isPaused'] = False
        changedJob = True
        print('    resumed')
        f.write('    resumed\n')
    if noquiesce is True:
        if job['environment'] == 'kPhysical':
            if job['physicalParams']['protectionType'] == 'kVolume':
                paramname = 'volumeProtectionTypeParams'
            else:
                paramname = 'fileProtectionTypeParams'
            if 'quiesce' in job['physicalParams'][paramname] and job['physicalParams'][paramname]['quiesce'] is True:
                job['physicalParams'][paramname]['quiesce'] = False
                if 'continueOnQuiesceFailure' in job['physicalParams'][paramname]:
                    del job['physicalParams'][paramname]['continueOnQuiesceFailure']
                changedJob = True
        if job['environment'] == 'kVMware':
            if job['vmwareParams']['appConsistentSnapshot'] is True:
                job['vmwareParams']['appConsistentSnapshot'] = False
                changedJob = True

    if changedJob is True:
        result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)

f.close()
print('\nOutput saved to %s\n' % outfile)
