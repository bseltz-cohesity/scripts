#!/usr/bin/env python
"""protect avid shares"""

### import pyhesity wrapper module
from pyhesity import *
from os import listdir
from os.path import isdir, join
from datetime import datetime
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-pn', '--proxyname', action='append', type=str)
parser.add_argument('-pl', '--proxylist', type=str)
parser.add_argument('-j', '--jobprefix', type=str, required=True)
parser.add_argument('-p', '--policyname', type=str, required=True)
parser.add_argument('-mp', '--mountpoint', action='append', type=str)
parser.add_argument('-ml', '--mountlist', type=str)
parser.add_argument('-s', '--showdelimiter', type=str, default='_')
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-f', '--maxlogfilesize', type=int, default=100000)

args = parser.parse_args()

vip = args.vip                # cluster name/ip
username = args.username      # username to connect to cluster
domain = args.domain          # domain of username (e.g. local, or AD domain)
proxies = args.proxyname      # name of server to protect
proxylist = args.proxylist    # file with server names
jobprefix = args.jobprefix    # name of protection job to add server to
policyname = args.policyname  # protection policy
mountpoint = args.mountpoint  # mount path of avid root
mountlist = args.mountlist    # file with mount points
showdelimiter = args.showdelimiter    # delimiter for show name
storagedomain = args.storagedomain    # storage domain for new job
policyname = args.policyname          # policy name for new job
starttime = args.starttime            # start time for new job
timezone = args.timezone              # time zone for new job
maxlogfilesize = args.maxlogfilesize  # max size to truncate log


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


proxies = gatherList(proxies, proxylist, name='proxies', required=True)
mountpoints = gatherList(mountpoint, mountlist, name='mount points', required=True)

# truncate log file
try:
    log = codecs.open('avidproxy-log.txt', 'r', 'utf-8')
    logfile = log.read()
    log.close()
    if len(logfile) > maxlogfilesize:
        lines = logfile.split('\n')
        linecount = int(len(lines) / 2)
        log = codecs.open('avidproxy-log.txt', 'w')
        log.writelines('\n'.join(lines[linecount:]))
        log.close()
except Exception:
    pass


def out(outstring):
    print(outstring)
    log.write('%s\n' % outstring)


def bailout():
    log.close()
    exit(1)


log = codecs.open('avidproxy-log.txt', 'a', 'utf-8')
date = datetime.now().strftime("%m/%d/%Y %H:%M:%S")
out('\n----------------------------\nStarted: %s\n----------------------------\n' % date)

# authenticate to Cohesity
apiauth(vip, username, domain)

# get existing jobs and sources
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
sources = api('get', 'protectionSources/registrationInfo?includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false')
nassources = [s for s in sources['rootNodes'] if s['rootNode']['environment'] == 'kGenericNas']

# get avid share and show lists
avidshares = []
for mountpoint in mountpoints:
    avidshares = avidshares + [d for d in listdir(mountpoint) if isdir(join(mountpoint, d))]

shows = list(set([d.split(showdelimiter)[0] for d in avidshares]))

proxyShares = {}
protectedShows = []

for proxy in proxies:

    proxyShares[proxy] = {'shares': [], 'job': None, 'newjob': False}

    # find or create job
    jobname = '%s-%s' % (jobprefix, proxy)
    job = [job for job in jobs if job['name'].lower() == jobname.lower()]

    if not job or len(job) < 1:
        proxyShares[proxy]['newjob'] = True
        out('Creating new job: %s' % jobname)

        # find protectionPolicy
        policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
        if len(policy) < 1:
            out("Policy '%s' not found!" % policyname)
            bailout()
        policyid = policy[0]['id']

        # find storage domain
        sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
        if len(sd) < 1:
            out("Storage domain %s not found!" % storagedomain)
            bailout()
        sdid = sd[0]['id']

        # parse starttime
        try:
            (hour, minute) = starttime.split(':')
            hour = int(hour)
            minute = int(minute)
            if hour < 0 or hour > 23 or minute < 0 or minute > 59:
                out('starttime is invalid!')
                bailout()
        except Exception:
            out('starttime is invalid!')
            bailout()

        # find registered source
        sourcename = '%s:%s' % (proxy, mountpoint)
        source = [s for s in nassources if s['rootNode']['name'].lower() == sourcename.lower()]
        if source is not None and len(source) > 0:
            sourceName = source[0]['rootNode']['name']
            sourceId = source[0]['rootNode']['id']
        else:
            out('registering protection source: %s' % sourcename)
            newSourceParams = {
                'entity': {
                    'type': 11,
                    'genericNasEntity': {
                        'protocol': 1,
                        'type': 1,
                        'path': sourcename
                    }
                },
                'entityInfo': {
                    'endpoint': sourcename,
                    'type': 11
                },
                'registeredEntityParams': {
                    'genericNasParams': {
                        'skipValidation': True
                    }
                }
            }
            result = api('post', '/backupsources', newSourceParams)
            sourceName = sourcename
            sourceId = result['entity']['id']

        # create new job
        job = {
            "name": jobname,
            "policyId": policyid,
            "priority": "kMedium",
            "storageDomainId": sdid,
            "description": "",
            "startTime": {
                "hour": hour,
                "minute": minute,
                "timeZone": timezone
            },
            "alertPolicy": {
                "backupRunStatus": [
                    "kFailure"
                ],
                "alertTargets": []
            },
            "sla": [
                {
                    "backupRunType": "kIncremental",
                    "slaMinutes": 60
                },
                {
                    "backupRunType": "kFull",
                    "slaMinutes": 120
                }
            ],
            "qosPolicy": "kBackupHDD",
            "abortInBlackouts": False,
            "isActive": True,
            "isPaused": False,
            "environment": "kGenericNas",
            "permissions": [],
            "genericNasParams": {
                "objects": [
                    {
                        "id": sourceId,
                        "name": sourceName
                    }
                ],
                "directCloudArchive": False,
                "nativeFormat": True,
                "indexingPolicy": {
                    "enableIndexing": True,
                    "includePaths": [
                        "/"
                    ],
                    "excludePaths": None
                },
                "continueOnError": True,
                "encryptionEnabled": False,
                "fileFilters": {
                    "includeList": [],
                    "excludeList": None
                }
            }
        }
        proxyShares[proxy]['job'] = job
    else:
        # existing job and paths
        proxyShares[proxy]['job'] = job[0]
        includePaths = proxyShares[proxy]['job']['genericNasParams']['fileFilters']['includeList']
        proxyShares[proxy]['shares'] = includePaths
        protectedShows = protectedShows + includePaths

# distribute shows
for show in sorted(shows):
    thisProxy = None

    # find existing show owner
    for share in [s for s in avidshares if s.split(showdelimiter)[0] == show]:
        sharepath = '/%s' % share
        for proxy in proxies:
            if sharepath in proxyShares[proxy]['shares']:
                thisProxy = proxy

    # find least busy proxy
    if thisProxy is None:
        minShows = 1000000000
        for proxy in proxies:
            shareCount = len(proxyShares[proxy]['shares'])
            if shareCount < minShows:
                minShows = shareCount
                thisProxy = proxy

    out('%s -> %s' % (show, thisProxy))

    # add show to proxy
    for share in [s for s in avidshares if s.split(showdelimiter)[0] == show]:
        sharepath = '/%s' % share
        if sharepath not in protectedShows:
            proxyShares[thisProxy]['shares'].append(sharepath)
            proxyShares[thisProxy]['job']['genericNasParams']['fileFilters']['includeList'].append(sharepath)
            proxyShares[thisProxy]['job']['genericNasParams']['fileFilters']['includeList'] = sorted(list(set(proxyShares[thisProxy]['job']['genericNasParams']['fileFilters']['includeList'])))
            protectedShows.append(sharepath)

# save jobs
for proxy in proxies:
    if len(proxyShares[proxy]['job']['genericNasParams']['fileFilters']['includeList']) > 0:
        if proxyShares[proxy]['newjob'] is True:
            result = api('post', 'data-protect/protection-groups', proxyShares[proxy]['job'], v=2)
        else:
            result = api('put', 'data-protect/protection-groups/%s' % proxyShares[proxy]['job']['id'], proxyShares[proxy]['job'], v=2)

log.close()
