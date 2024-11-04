#!/usr/bin/env python
"""Protect AHV VMs Using Python"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-s', '--sourcename', type=str, required=True)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-n', '--vmname', action='append', type=str)
parser.add_argument('-l', '--vmlist', type=str)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)
parser.add_argument('-fs', '--fullsla', type=int, default=120)

args = parser.parse_args()

vip = args.vip                        # cluster name/ip
username = args.username              # username to connect to cluster
domain = args.domain                  # domain of username (e.g. local, or AD domain)
password = args.password              # password or API key
useApiKey = args.useApiKey            # use API key for authentication
sourcename = args.sourcename          # name of vcd source to protect
jobname = args.jobname                # name of protection job to add server to
vmnames = args.vmname                 # name of vm to add (repeat for multiple)
vmlist = args.vmlist                  # text file of vms to add (one per line)
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
incrementalsla = args.incrementalsla  # incremental SLA for new job
fullsla = args.fullsla                # full SLA for new job

# authenticate to Cohesity
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# gather vm list
if vmnames is None:
    vmnames = []
if vmlist is not None:
    f = open(vmlist, 'r')
    vmnames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

if len(vmnames) == 0:
    print('no vm specified')
    exit()

# get AHV registered source
sources = [s for s in api('get', 'protectionSources?environments=kAcropolis') if s['protectionSource']['name'].lower() == sourcename.lower()]
if not sources or len(sources) == 0:
    print('AHV source %s not registered' % sourcename)
    exit(1)
else:
    source = sources[0]

# get sourceIds of VMs to protect
sourceIds = []
for vmname in vmnames:
    vm = [s for s in source['nodes'] if s['protectionSource']['name'].lower() == vmname.lower()]
    if not vm or len(vm) == 0:
        print('VM %s not found' % vmname)
    else:
        print('protecting vm %s' % vmname)
        sourceIds.append(vm[0]['protectionSource']['id'])

# get job info
newJob = False
job = [j for j in api('get', 'protectionJobs?environment=kAcropolis') if j['name'].lower() == jobname.lower()]

if not job or len(job) == 0:
    # create new job
    newJob = True

    # find protectionPolicy
    if policyname is None:
        print('Policy name required for new job')
        exit(1)
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']

    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
    if len(sd) < 1:
        print("Storage domain %s not found!" % storagedomain)
        exit(1)
    sdid = sd[0]['id']

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

    print("Creating new Job '%s'" % jobname)

    job = {
        "policyId": policyid,
        "environment": "kAcropolis",
        "parentSourceId": source['protectionSource']['id'],
        "LeverageSanTransport": None,
        "timezone": timezone,
        "viewBoxId": sdid,
        "priority": "kLow",
        "name": jobname,
        "indexingPolicy": {
            "allowPrefixes": [
                "/"
            ],
            "disableIndexing": False,
            "denyPrefixes": [
                "/$Recycle.Bin",
                "/Windows",
                "/Program Files",
                "/Program Files (x86)",
                "/ProgramData",
                "/System Volume Information",
                "/Users/*/AppData",
                "/Recovery",
                "/var",
                "/usr",
                "/sys",
                "/proc",
                "/lib",
                "/grub",
                "/grub2"
            ]
        },
        "sourceIds": sourceIds,
        "startTime": {
            "minute": minute,
            "hour": hour
        }
    }
else:
    # update existing job
    job = job[0]

    if job['parentSourceId'] != source['protectionSource']['id']:
        print('Job %s protects a different AHV cluster' % jobname)
        exit(1)

    print("Updating Job '%s'" % jobname)
    job['sourceIds'] += sourceIds

if newJob is True:
    result = api('post', 'protectionJobs', job)
else:
    job['sourceIds'] = list(set(job['sourceIds']))
    result = api('put', 'protectionJobs/%s' % job['id'], job)
