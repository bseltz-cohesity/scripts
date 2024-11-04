#!/usr/bin/env python

from pyhesity import *
from basic_api import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-g', '--gpfs', type=str, required=True)
parser.add_argument('-gu', '--gpfsuser', type=str, required=True)
parser.add_argument('-gn', '--gpfsnode', type=str, required=True)
parser.add_argument('-gp', '--gpfspwd', type=str, default=None)
parser.add_argument('-i', '--include', action='append', type=str)
parser.add_argument('-il', '--includelist', type=str)
parser.add_argument('-e', '--exclude', action='append', type=str)
parser.add_argument('-el', '--excludelist', type=str)
parser.add_argument('-f', '--fileset', action='append', type=str)
parser.add_argument('-fl', '--filesetlist', type=str)
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-sd', '--storagedomain', type=str, default='DefaultStorageDomain')
parser.add_argument('-p', '--policyname', type=str, default=None)
parser.add_argument('-tz', '--timezone', type=str, default='US/Eastern')
parser.add_argument('-st', '--starttime', type=str, default='21:00')
parser.add_argument('-z', '--pause', action='store_true')
parser.add_argument('-is', '--incrementalsla', type=int, default=60)    # incremental SLA minutes
parser.add_argument('-fs', '--fullsla', type=int, default=120)          # full SLA minutes
parser.add_argument('-q', '--qospolicy', type=str, choices=['kBackupHDD', 'kBackupSSD', 'kBackupAll'], default='kBackupHDD')
parser.add_argument('-pr', '--prescript', type=str, default='prescript.sh')
parser.add_argument('-po', '--postscript', type=str, default='postscript.sh')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
gpfs = args.gpfs
gpfsuser = args.gpfsuser
gpfsnode = args.gpfsnode
gpfspwd = args.gpfspwd
includes = args.include
includelist = args.includelist
excludes = args.exclude
excludelist = args.excludelist
filesets = args.fileset
filesetlist = args.filesetlist
jobname = args.jobname
policyname = args.policyname
starttime = args.starttime
timezone = args.timezone
incrementalsla = args.incrementalsla
fullsla = args.fullsla
storagedomain = args.storagedomain
pause = args.pause
qospolicy = args.qospolicy
prescript = args.prescript
postscript = args.postscript

if noprompt is True:
    prompt = False
else:
    prompt = None

if pause:
    isPaused = True
else:
    isPaused = False


# gather list function
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
        print('*** no %s specified' % name)
        exit()
    return items


# get lists
filesetnames = gatherList(filesets, filesetlist, name='filesets', required=True)
includePaths = gatherList(includes, includelist, name='include paths', required=False)
excludePaths = gatherList(excludes, excludelist, name='exclude paths', required=False)

# authenticate to cohesity (start) =================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('*** -clustername is required when connecting to Helios or MCM')
        exit()

# exit if not authenticated
if apiconnected() is False:
    print('*** Cohesity authentication failed')
    exit(1)
else:
    print('Connected to Cohesity')
# authenticate to cohesity (end) ===================================================

# authenticate to gpfs (start) =====================================================

bapiauth(endpoint=gpfs, username=gpfsuser, password=gpfspwd)

cluster = bapi('get', '/scalemgmt/v2/cluster')
if cluster is None or 'cluster' not in cluster:
    print('*** Failed to connect to GPFS %s' % gpfs)
    exit(1)
else:
    print('Connected to GPFS')

# authenticate to gpfs (end) =======================================================

# get protection source
sources = api('get', 'protectionSources/registrationInfo?environments=kPhysical')

if sources is None or 'rootNodes' not in sources or len(sources['rootNodes']) == 0:
    print('*** No physical sources registered')
    exit(1)
thisSource = [r for r in sources['rootNodes'] if r['rootNode']['name'].lower() == gpfsnode.lower()]
if thisSource is None or len(thisSource) == 0:
    print('*** %s is not a registered protection source' % gpfsnode)
    exit(1)
else:
    thisSource = thisSource[0]
    thisSourceId = thisSource['rootNode']['id']

# get job info
newJob = False
protectionGroups = api('get', 'data-protect/protection-groups?isDeleted=false&isActive=true', v=2)
jobs = protectionGroups['protectionGroups']
job = [job for job in jobs if job['name'].lower() == jobname.lower()]

if not job or len(job) < 1:
    newJob = True

    # find protectionPolicy
    if policyname is None:
        print('*** Policy name required for new job')
        exit(1)
    policy = [p for p in api('get', 'protectionPolicies') if p['name'].lower() == policyname.lower()]
    if len(policy) < 1:
        print("*** Policy '%s' not found!" % policyname)
        exit(1)
    policyid = policy[0]['id']

    # find storage domain
    sd = [sd for sd in api('get', 'viewBoxes') if sd['name'].lower() == storagedomain.lower()]
    if len(sd) < 1:
        print("*** Storage domain %s not found!" % storagedomain)
        exit(1)
    sdid = sd[0]['id']

    # parse starttime
    try:
        (hour, minute) = starttime.split(':')
        hour = int(hour)
        minute = int(minute)
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            print('*** starttime is invalid!')
            exit(1)
    except Exception:
        print('*** starttime is invalid!')
        exit(1)

    job = {
        "policyId": policyid,
        "startTime": {
            "hour": int(hour),
            "minute": int(minute),
            "timeZone": timezone
        },
        "priority": "kMedium",
        "sla": [
            {
                "backupRunType": "kFull",
                "slaMinutes": fullsla
            },
            {
                "backupRunType": "kIncremental",
                "slaMinutes": incrementalsla
            }
        ],
        "qosPolicy": qospolicy,
        "abortInBlackouts": False,
        "storageDomainId": sdid,
        "name": jobname,
        "environment": "kPhysical",
        "isPaused": isPaused,
        "description": "",
        "alertPolicy": {
            "backupRunStatus": [
                "kFailure"
            ],
            "alertTargets": []
        },
        "physicalParams": {
            "protectionType": "kFile",
            "fileProtectionTypeParams": {
                "objects": [],
                "indexingPolicy": {
                    "enableIndexing": True,
                    "includePaths": [
                        "/"
                    ],
                    "excludePaths": [
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
                        "/grub2",
                        "/opt",
                        "/splunk"
                    ]
                },
                "performSourceSideDeduplication": False,
                "performBrickBasedDeduplication": False,
                "prePostScript": {},
                "globalExcludePaths": [],
                "ignorableErrors": []
            }
        }
    }

else:
    job = job[0]

fscache = {}
fsetcache = {}
processedIncludePaths = []
sIncludePaths = []
sExcludePaths = []
fsetNames = []

# enumerate file systems
print('Enumerating file systems...')
filesystems = bapi('get', '/scalemgmt/v2/filesystems')
if filesystems is None or len(filesystems) == 0 or 'filesystems' not in filesystems or len(filesystems['filesystems']) == 0:
    print('*** no filesystems found on gpfs cluster')
    exit(1)

# enumerate selected filesets
print('Enumerating filesets...')
for filesetname in filesetnames:
    fsparts = filesetname.split('/')
    if len(fsparts) != 2:
        print('*** invalid filesetname %s' % filesetname)
        exit(1)
    fsname = fsparts[0]
    fsetname = fsparts[1]
    filesystem = [f for f in filesystems['filesystems'] if f['name'].lower() == fsname.lower()]
    if filesystem is None or len(filesystem) == 0:
        print('*** file system %s not found on GPFS cluster' % fsname)
        exit(1)
    else:
        filesystem = filesystem[0]
    if filesystem['name'] not in fscache:
        filesets = bapi('get', '/scalemgmt/v2/filesystems/%s/filesets' % filesystem['name'])
        fscache[filesystem['name']] = filesets
    filesets = fscache[filesystem['name']]
    if filesets is None or len(filesets) == 0 or 'filesets' not in filesets or len(filesets['filesets']) == 0:
        print('*** fileset %s not found in filesystem %s' % (fsetname, fsname))
        exit(1)
    fileset = [f for f in filesets['filesets'] if f['filesetName'].lower() == fsetname.lower()]
    if fileset is None or len(fileset) == 0:
        print('*** fileset %s not found in filesystem %s' % (fsetname, fsname))
        exit(1)
    else:
        fileset = fileset[0]
    if '%s/%s' % (filesystem['name'], fileset['filesetName']) not in fsetcache:
        filesetInfo = bapi('get', '/scalemgmt/v2/filesystems/%s/filesets/%s' % (filesystem['name'], fileset['filesetName']))
        fsetcache['%s/%s' % (filesystem['name'], fileset['filesetName'])] = filesetInfo
    filesetInfo = fsetcache['%s/%s' % (filesystem['name'], fileset['filesetName'])]
    if filesetInfo is None or 'filesets' not in filesetInfo or len(filesetInfo['filesets']) == 0:
        print('*** failed to get filesetInfo for %s/%s' % (fsname, fsetname))
        exit(1)
    f = filesetInfo['filesets'][0]
    fpath = f['config']['path']
    spath = '%s/.snapshots/Cohesity-%s' % (fpath, thisSource['rootNode']['name'])
    if len(includePaths) == 0:
        includePaths.append('%s/' % fpath)
    # convert paths to snapshot paths
    for includePath in includePaths:
        if includePath.startswith(fpath):
            fsetNames.append('%s/%s' % (filesystem['name'], fileset['filesetName']))
            tailPath = includePath.split(fpath, 1)
            if len(tailPath) == 2:
                sIncludePath = '%s%s' % (spath, tailPath[1])
                sIncludePaths.append(sIncludePath)
                processedIncludePaths.append(includePath)
                for excludePath in excludePaths:
                    if excludePath.startswith(includePath):
                        tailPath = excludePath.split(fpath, 1)
                        if len(tailPath) == 2:
                            sExcludePath = '%s%s' % (spath, tailPath[1])
                            sExcludePaths.append(sExcludePath)


if len(sIncludePaths) > 0:
    existingObject = [o for o in job['physicalParams']['fileProtectionTypeParams']['objects'] if o['id'] == thisSourceId]
    job['physicalParams']['fileProtectionTypeParams']['objects'] = [o for o in job['physicalParams']['fileProtectionTypeParams']['objects'] if o['id'] != thisSourceId]
    print('Protecting %s' % thisSource['rootNode']['name'])
    if existingObject is not None and len(existingObject) > 0:
        newObject = existingObject[0]
    else:
        newObject = {
            "id": thisSourceId,
            "filePaths": [],
            "usesPathLevelSkipNestedVolumeSetting": False,
            "nestedVolumeTypesToSkip": [
                "autofs"
            ],
            "followNasSymlinkTarget": False
        }
    for sIncludePath in sIncludePaths:
        print('    Including %s' % sIncludePath)
        existingFilePath = [p for p in newObject['filePaths'] if p['includedPath'].startswith(sIncludePath)]
        newObject['filePaths'] = [p for p in newObject['filePaths'] if not p['includedPath'].startswith(sIncludePath)]
        if existingFilePath is not None and len(existingFilePath) > 0:
            newFilePath = existingFilePath[0]
        else:
            newFilePath = {
                "includedPath": sIncludePath,
                "excludedPaths": [],
                "skipNestedVolumes": False
            }
        for sExcludePath in sExcludePaths:
            print('    Excluding %s' % sExcludePath)
            if sExcludePath.startswith(sIncludePath):
                newFilePath['excludedPaths'].append(sExcludePath)
        newFilePath['excludedPaths'] = list(set(newFilePath['excludedPaths']))
        newObject['filePaths'].append(newFilePath)
    job['physicalParams']['fileProtectionTypeParams']['objects'].append(newObject)
else:
    print('no paths to include')
    exit()
if 'prePostScript' not in job['physicalParams']['fileProtectionTypeParams'] or job['physicalParams']['fileProtectionTypeParams']['prePostScript'] is None or job['physicalParams']['fileProtectionTypeParams']['prePostScript'] == {}:
    job['physicalParams']['fileProtectionTypeParams']['prePostScript'] = {
        "preScript": {
            "path": prescript,
            "params": ','.join(fsetNames),
            "timeoutSecs": 900,
            "continueOnError": False
        },
        "postScript": {
            "path": postscript,
            "params": ','.join(fsetNames),
            "timeoutSecs": 900
        }
    }
elif 'postScript' not in job['physicalParams']['fileProtectionTypeParams']['prePostScript'] or job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript'] is None or job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript'] == {}:
    job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript'] = {
        "path": postscript,
        "params": ','.join(fsetNames),
        "timeoutSecs": 900
    }
else:
    job['physicalParams']['fileProtectionTypeParams']['prePostScript']['preScript']['path'] = prescript
    params = job['physicalParams']['fileProtectionTypeParams']['prePostScript']['preScript']['params'].split(',')
    params = list(set(params + fsetNames))
    job['physicalParams']['fileProtectionTypeParams']['prePostScript']['preScript']['params'] = ','.join(params)
    job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript']['path'] = postscript
    params = job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript']['params'].split(',')
    params = list(set(params + fsetNames))
    job['physicalParams']['fileProtectionTypeParams']['prePostScript']['postScript']['params'] = ','.join(params)

for includePath in includePaths:
    if includePath not in processedIncludePaths:
        print('... skipped %s (file set not included)' % includePath)

if newJob is True:
    print('Creating protection job %s' % jobname)
    result = api('post', 'data-protect/protection-groups', job, v=2)
else:
    print('Updating protection job %s' % job['name'])
    result = api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
