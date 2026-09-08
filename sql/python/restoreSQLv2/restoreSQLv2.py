#!/usr/bin/env python
"""Recover MS SQL databases using python (v2 recovery API)"""

## version 2026-09-08

### import pyhesity wrapper module
from pyhesity import *
from pyhesity import COHESITY_API
import json
import os
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useapikey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)

parser.add_argument('-ss', '--sourceserver', type=str, required=True)
parser.add_argument('-sd', '--sourcedb', action='append', type=str, default=None)
parser.add_argument('-sdl', '--sourcedblist', type=str, default=None)
parser.add_argument('-adb', '--alldbs', action='store_true')
parser.add_argument('-isdb', '--includesystemdbs', action='store_true')
parser.add_argument('-si', '--sourceinstance', type=str, default=None)
parser.add_argument('-sn', '--sourcenodes', action='append', type=str, default=None)

parser.add_argument('-ts', '--targetserver', type=str, default=None)
parser.add_argument('-ti', '--targetinstance', type=str, default=None)
parser.add_argument('-td', '--targetdb', type=str, default=None)
parser.add_argument('-pre', '--prefix', type=str, default=None)
parser.add_argument('-suf', '--suffix', type=str, default=None)

parser.add_argument('-mdf', '--mdffolder', type=str, default=None)
parser.add_argument('-ldf', '--ldffolder', type=str, default=None)
parser.add_argument('-ffp', '--flatfilepath', type=str, default=None)
parser.add_argument('-ndf', '--ndffolder', action='append', type=str, default=None,
                     help='secondary (ndf) data file mapping as filenamePattern=directory, may be repeated')

parser.add_argument('-nr', '--norecovery', action='store_true')
parser.add_argument('-nst', '--nostop', action='store_true')
parser.add_argument('-lt', '--logtime', type=str, default=None, help="format: 'YYYY-MM-DD HH:MM:SS'")
parser.add_argument('-lrd', '--lograngedays', type=int, default=14)
parser.add_argument('-nt', '--newerthan', type=int, default=None)
parser.add_argument('-ow', '--overwrite', action='store_true')
parser.add_argument('-kc', '--keepcdc', action='store_true')
parser.add_argument('-ctl', '--capturetaillogs', action='store_true')

parser.add_argument('-w', '--wait', action='store_true')
parser.add_argument('-pr', '--progress', action='store_true')
parser.add_argument('-ps', '--pagesize', type=int, default=100)
parser.add_argument('-dpr', '--dbsperrecovery', type=int, default=100)
parser.add_argument('-st', '--sleeptime', type=int, default=60)

parser.add_argument('-ep', '--exportpaths', action='store_true')
parser.add_argument('-ip', '--importpaths', action='store_true')
parser.add_argument('-sp', '--showpaths', action='store_true')
parser.add_argument('-cm', '--commit', action='store_true')
parser.add_argument('-nl', '--nologs', action='store_true')
parser.add_argument('-dbg', '--dbg', action='store_true')
parser.add_argument('-ia', '--includearchives', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useapikey = args.useapikey
password = args.password
noprompt = args.noprompt
tenant = args.tenant
mfacode = args.mfacode

sourceserver = args.sourceserver
sourcedb = args.sourcedb
sourcedblist = args.sourcedblist
alldbs = args.alldbs
includesystemdbs = args.includesystemdbs
sourceinstance = args.sourceinstance
sourcenodes = args.sourcenodes

if args.targetserver is None:
    targetserver = sourceserver
else:
    targetserver = args.targetserver
targetinstance = args.targetinstance
targetdb = args.targetdb
prefix = args.prefix
suffix = args.suffix

mdffolder = args.mdffolder
if args.ldffolder is None:
    ldffolder = mdffolder
else:
    ldffolder = args.ldffolder
flatfilepath = args.flatfilepath
ndffolders = {}
if args.ndffolder:
    for item in args.ndffolder:
        if '=' in item:
            k, v = item.split('=', 1)
            ndffolders[k] = v

norecovery = args.norecovery
nostop = args.nostop  # noqa: F841 (unused - kept for parity with source script)
logtime = args.logtime
lograngedays = args.lograngedays
newerthan = args.newerthan
overwrite = args.overwrite
keepcdc = args.keepcdc
capturetaillogs = args.capturetaillogs

wait = args.wait
progress = args.progress
pagesize = args.pagesize
dbsperrecovery = args.dbsperrecovery
sleeptime = args.sleeptime
if sleeptime < 20:
    sleeptime = 20

exportpaths = args.exportpaths
importpaths = args.importpaths
showpaths = args.showpaths
commit = args.commit
nologs = args.nologs
dbg = args.dbg
includearchives = args.includearchives

if dbg:
    enableCohesityAPIDebugger()


### case-insensitive helpers (PowerShell string comparisons are case-insensitive by default)
def ieq(a, b):
    if a is None or b is None:
        return a == b
    return str(a).lower() == str(b).lower()


def iin(a, itemlist):
    if a is None:
        return False
    return str(a).lower() in [str(x).lower() for x in itemlist]


if not commit and not exportpaths and not showpaths:
    print('Running in test mode. Please use the -commit switch to perform the recoveries')

conflictingselections = False
if alldbs:
    if sourcedblist or (sourcedb and len(sourcedb) > 0):
        conflictingselections = True
if sourcedblist:
    if sourcedb and len(sourcedb) > 0:
        conflictingselections = True
if conflictingselections is True:
    print('Conflicting DB selections. Please use only one of -alldbs, -sourcedblist, -sourcedb')
    exit(1)


### gather list from command line params and file
def gatherlist(param=None, filepath=None, required=True, name='items'):
    items = []
    if param:
        for item in param:
            for piece in str(item).split(','):
                piece = piece.strip()
                if piece != '':
                    items.append(piece)
    if filepath:
        if os.path.isfile(filepath):
            with open(filepath, 'r') as f:
                for line in f.readlines():
                    line = line.strip()
                    if line != '':
                        items.append(line)
        else:
            print('Text file %s not found!' % filepath)
            exit(1)
    if required is True and len(items) == 0:
        print('No %s specified' % name)
        exit(1)
    return sorted(set(items))


sourcedbnames = gatherlist(param=sourcedb, filepath=sourcedblist, required=False, name='DBs')
sourcenodelist = []
if sourcenodes:
    sourcenodelist = gatherlist(param=sourcenodes, required=False, name='source nodes')

# authentication =============================================================
# demand clustername for Helios/MCM
if (vip.lower() == 'helios.cohesity.com' or mcm) and not clustername:
    print('-c, --clustername is required when connecting to Helios/MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useapikey,
        helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

# exit on failed authentication
if apiconnected() is False:
    print('Not authenticated')
    exit(1)

# select helios/mcm managed cluster
if COHESITY_API['USING_HELIOS'] is True:
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =========================================================

paramname = 'recoverAppParams'
if flatfilepath:
    paramname = 'recoverAppFilesParams'
    flatfilepath = flatfilepath.title()

if not showpaths and not exportpaths:
    cluster = api('get', 'cluster')
    if cluster is None or cluster.get('clusterSoftwareVersion', '0') < '6.8.1':
        print('This script requires Cohesity 6.8.1 or later')
        exit(1)

### import file paths
scriptdir = os.path.dirname(os.path.realpath(__file__))
exportfilepath = os.path.join(scriptdir, '%s.json' % sourceserver)
importedfileinfo = None
if importpaths:
    if not os.path.isfile(exportfilepath):
        print('Import file %s not found' % exportfilepath)
        exit(1)
    with open(exportfilepath, 'r') as f:
        importedfileinfo = json.load(f)

newerthanusecs = None
if newerthan:
    newerthanusecs = timeAgo(newerthan, 'days')

### find all databases on server
if alldbs or exportpaths:
    dbfrom = 0
    allsearch = api('get', '/searchvms?environment=SQL&entityTypes=kSQL&vmName=%s&size=%s&from=%s' % (sourceserver, pagesize, dbfrom))
    dbresults = {'vms': []}
    if allsearch is not None and allsearch.get('count', 0) > 0:
        while True:
            dbresults['vms'] = dbresults['vms'] + allsearch.get('vms', [])
            if allsearch.get('count', 0) > (pagesize + dbfrom):
                dbfrom += pagesize
                allsearch = api('get', '/searchvms?environment=SQL&entityTypes=kSQL&vmName=%s&size=%s&from=%s' % (sourceserver, pagesize, dbfrom))
            else:
                break

    dbresults['vms'] = [vm for vm in dbresults['vms'] if iin(sourceserver, vm['vmDocument']['objectAliases'])]

    if len(dbresults['vms']) == 0:
        print('no DBs found for %s' % sourceserver)
        exit(1)

    # exportFileInfo
    if exportpaths:
        fileinfovec = []
        for vm in dbresults['vms']:
            sqlentity = vm['vmDocument']['objectId']['entity'].get('sqlEntity', {})
            if 'dbFileInfoVec' in sqlentity:
                dbname = vm['vmDocument']['objectName']
                fileinfo = sqlentity['dbFileInfoVec']
                fileinfovec.append({'name': dbname, 'fileInfo': fileinfo})
        with open(exportfilepath, 'w') as f:
            json.dump(fileinfovec, f, indent=4)
        print('Exported file paths to %s' % exportfilepath)
        exit(0)

    # filter by source instance
    if sourceinstance:
        dbresults['vms'] = [vm for vm in dbresults['vms'] if ieq(vm['vmDocument']['objectName'].split('/')[0], sourceinstance)]
        if len(dbresults['vms']) == 0:
            print('no DBs found for %s/%s' % (sourceserver, sourceinstance))
            exit(1)

    # filter by source AAG nodes
    if sourcenodelist:
        dbresults['vms'] = [vm for vm in dbresults['vms']
                             if any(iin(node, vm['vmDocument']['objectAliases']) for node in sourcenodelist)]
        if len(dbresults['vms']) == 0:
            print('no DBs found for source nodes %s' % ', '.join(sourcenodelist))
            exit(1)

    # filter by age of most recent backup
    if newerthanusecs:
        dbresults['vms'] = [vm for vm in dbresults['vms'] if vm['vmDocument']['versions'][0]['instanceId']['jobStartTimeUsecs'] >= newerthanusecs]
        if len(dbresults['vms']) == 0:
            print('no DBs found newer than %s days' % newerthan)
            exit(1)

    sourcedbnames = sorted(set([vm['vmDocument']['objectName'] for vm in dbresults['vms']]))

    if not includesystemdbs:
        sourcedbnames = [n for n in sourcedbnames if n.split('/')[-1].upper() not in ('MASTER', 'MODEL', 'MSDB')]

if len(sourcedbnames) == 0:
    print('No DBs specified for restore')
    exit(1)

if len(sourcedbnames) > 1 and targetdb:
    print("Can't specify -targetdb when more than one database is specified. Please use -prefix or -suffix for renaming")
    exit(1)

### find target server
targetentity = None
registrationinfo = api('get', 'protectionSources/registrationInfo?environments=kSQL&includeEntityPermissionInfo=false&includeApplicationsTreeInfo=false&pruneNonCriticalInfo=true')
if registrationinfo is not None:
    for rootnode in registrationinfo.get('rootNodes', []):
        if ieq(rootnode['rootNode']['name'], targetserver):
            targetentity = rootnode
            break

if targetentity is None and not showpaths:
    print('Target Server %s Not Found' % targetserver)
    exit(1)

targetentityid = targetentity['rootNode']['id'] if targetentity is not None else ''
targetsource = api('get', 'protectionSources?numLevels=1&id=%s' % targetentityid)

from datetime import datetime
restoredate = datetime.now().strftime('%Y-%m-%d_%H:%M:%S')

desiredpit = dateToUsecs()
if logtime:
    desiredpit = dateToUsecs(logtime)

### recovery params
skippeddbs = []
recoveryparamnum = 1
dbsselected = 0
recoveryids = []


def newrecoveryparams(paramnum):
    if flatfilepath:
        return {
            'name': 'Recover_MS_SQL_%s_%s_%s' % (sourceserver, restoredate, paramnum),
            'snapshotEnvironment': 'kSQL',
            'mssqlParams': {
                'recoveryAction': 'RecoverAppFiles',
                'recoverAppFilesParams': []
            }
        }
    else:
        return {
            'name': 'Recover_MS_SQL_%s_%s_%s' % (sourceserver, restoredate, paramnum),
            'snapshotEnvironment': 'kSQL',
            'mssqlParams': {
                'recoveryAction': 'RecoverApps',
                'recoverAppParams': []
            }
        }


recoveryparams = newrecoveryparams(recoveryparamnum)

for sourcedbname in sorted(sourcedbnames):
    if '/' not in sourcedbname:
        if sourceinstance:
            sourcedbname = '%s/%s' % (sourceinstance, sourcedbname)
        else:
            sourcedbname = 'MSSQLSERVER/%s' % sourcedbname
    thissourceinstance, shortdbname = sourcedbname.split('/', 1)

    search = api('get', 'data-protect/search/protected-objects?snapshotActions=RecoverApps&searchString=%s&environments=kSQL' % shortdbname, v=2)
    objects = search.get('objects', []) if search is not None else []

    def objmatches(o):
        name = o.get('name', '')
        if ieq(name, sourcedbname):
            return True
        if '/' not in name and ieq(name, shortdbname):
            return True
        return False

    objects = [o for o in objects if objmatches(o)]

    def hostmatches(o):
        mssqlparams = o.get('mssqlParams', {})
        hostname = mssqlparams.get('hostInfo', {}).get('name')
        aagname = mssqlparams.get('aagInfo', {}).get('name')
        return ieq(hostname, sourceserver) or ieq(aagname, sourceserver)

    objects = [o for o in objects if hostmatches(o)]

    if len(objects) == 0:
        print('%s not found on server %s' % (sourcedbname, sourceserver))
        continue

    if dbg:
        with open('debug-search1.json', 'w') as f:
            json.dump(search, f, indent=4)

    ranges = []
    for obj in objects:
        objid = obj['id']
        for protection in sorted(obj.get('latestSnapshotsInfo', []), key=lambda p: p['protectionRunStartTimeUsecs'], reverse=True):
            protectiongroupid = protection['protectionGroupId']
            snapshots = api('get', 'data-protect/objects/%s/snapshots?protectionGroupIds=%s' % (objid, protectiongroupid), v=2)
            snaps = snapshots.get('snapshots', []) if snapshots is not None else []
            snaps = [s for s in snaps if s['runStartTimeUsecs'] <= desiredpit]
            if newerthanusecs:
                snaps = [s for s in snaps if s['runStartTimeUsecs'] >= newerthanusecs]
            if not includearchives:
                snaps = [s for s in snaps if s.get('snapshotTargetType') == 'Local']
            else:
                if COHESITY_API['USING_HELIOS'] is not True:
                    snaps = [s for s in snaps if 'ownershipContext' not in s or s.get('ownershipContext') != 'FortKnox']
            snaps = sorted(snaps, key=lambda s: (s['runStartTimeUsecs'], s.get('snapshotTargetType', '')), reverse=True)
            if len(snaps) > 0:
                snapshot = snaps[0]
                ranges.append({'object': obj, 'snapshot': snapshot, 'protection': protection, 'pit': snapshot['runStartTimeUsecs']})

    print('\n%s' % objects[0].get('name'))
    if len(ranges) > 0:
        thisrange = sorted(ranges, key=lambda r: r['snapshot']['runStartTimeUsecs'], reverse=True)[0]
    else:
        print('    No snapshots for %s, skipping' % logtime)
        continue

    if not nologs:
        clusterid, clusterincarnationid, jobid = thisrange['protection']['protectionGroupId'].split(':')

        lograngelimitusecs = desiredpit - (lograngedays * 86400000000)
        lograngestart = thisrange['pit']
        if lograngelimitusecs > lograngestart:
            lograngestart = lograngelimitusecs

        # PIT lookup
        pitquery = {
            'jobUids': [
                {
                    'clusterId': int(clusterid),
                    'clusterIncarnationId': int(clusterincarnationid),
                    'id': int(jobid)
                }
            ],
            'environment': 'kSQL',
            'protectionSourceId': thisrange['object']['id'],
            'startTimeUsecs': lograngestart,
            'endTimeUsecs': desiredpit
        }
        logs = api('post', 'restore/pointsForTimeRange', pitquery)
        if logs is not None and 'timeRanges' in logs:
            for timerange in logs['timeRanges']:
                if desiredpit >= timerange['startTimeUsecs']:
                    if desiredpit >= timerange['endTimeUsecs'] and timerange['endTimeUsecs'] > thisrange['pit']:
                        thisrange['pit'] = timerange['endTimeUsecs']
                    elif desiredpit < timerange['endTimeUsecs']:
                        thisrange['pit'] = desiredpit

    thissourceserver = objects[0].get('mssqlParams', {}).get('hostInfo', {}).get('name')
    targethostid = objects[0].get('mssqlParams', {}).get('hostInfo', {}).get('id')

    if not showpaths:
        print('    Selected Snapshot %s (%s)' % (usecsToDate(thisrange['snapshot']['runStartTimeUsecs']), thisrange['snapshot'].get('snapshotTargetType')))
        if desiredpit and desiredpit != thisrange['pit']:
            print('    Best available PIT is %s' % usecsToDate(thisrange['pit']))
        print('    Selected PIT %s' % usecsToDate(thisrange['pit']))

    if flatfilepath:
        thisparam = {
            'snapshotId': thisrange['snapshot']['id'],
            'targetEnvironment': 'kSQL',
            'sqlTargetParams': {
                'flatFileDirectoryLocation': flatfilepath,
                'overwriteExistingFiles': False,
                'host': {
                    'id': int(targethostid)
                },
                'originalSourceConfig': {
                    'keepCdc': False,
                    'withNoRecovery': False,
                    'captureTailLogs': False
                }
            }
        }
        if overwrite:
            thisparam['sqlTargetParams']['overwriteExistingFiles'] = True
    else:
        thisparam = {
            'snapshotId': thisrange['snapshot']['id'],
            'targetEnvironment': 'kSQL',
            'sqlTargetParams': {
                'recoverToNewSource': False,
                'originalSourceConfig': {
                    'keepCdc': False,
                    'withNoRecovery': False,
                    'captureTailLogs': False
                }
            }
        }

    if not nologs:
        if thisrange['pit'] != thisrange['snapshot']['runStartTimeUsecs']:
            thisparam['pointInTimeUsecs'] = thisrange['pit']
            thisparam['sqlTargetParams']['originalSourceConfig']['restoreTimeUsecs'] = thisrange['pit']

    targetconfig = thisparam['sqlTargetParams']['originalSourceConfig']
    if capturetaillogs:
        targetconfig['captureTailLogs'] = True

    # rename DB
    newdbname = shortdbname
    renamedb = False
    if targetdb or prefix or suffix:
        renamedb = True
        if targetdb:
            newdbname = targetdb
        if prefix:
            newdbname = '%s-%s' % (prefix, newdbname)
        if suffix:
            newdbname = '%s-%s' % (newdbname, suffix)
        targetconfig['newDatabaseName'] = newdbname

    # recover to alternate instance
    alternateinstance = False
    if not ieq(targetserver, thissourceserver) or (targetinstance and not ieq(targetinstance, thissourceinstance)):
        alternateinstance = True
        if not targetinstance:
            targetinstance = 'MSSQLSERVER'
        targetinstanceobj = None
        for node in targetsource[0].get('applicationNodes', []) if targetsource is not None else []:
            if ieq(node['protectionSource']['name'], targetinstance):
                targetinstanceobj = node
                break
        if targetinstanceobj is None:
            print('    Target instance %s/%s not found' % (targetentity['rootNode']['name'] if targetentity else targetserver, targetinstance))
            exit(1)
        if flatfilepath:
            thisparam['sqlTargetParams']['host']['id'] = int(targetentity['rootNode']['id'])
        else:
            thisparam['sqlTargetParams'] = {
                'recoverToNewSource': True,
                'newSourceConfig': {
                    'host': {
                        'id': targetentity['rootNode']['id']
                    },
                    'instanceName': targetinstanceobj['protectionSource']['name'],
                    'keepCdc': False,
                    'withNoRecovery': False,
                    'databaseName': newdbname
                }
            }
            targetconfig = thisparam['sqlTargetParams']['newSourceConfig']
            if not nologs:
                if thisrange['pit'] != thisrange['snapshot']['runStartTimeUsecs']:
                    targetconfig['restoreTimeUsecs'] = thisrange['pit']
    else:
        if renamedb is False and not flatfilepath:
            if not overwrite and not showpaths:
                print('Please use -overwrite to overwrite original database(s)')
                exit(1)

    # file destinations
    if not flatfilepath and (alternateinstance is True or renamedb is True or showpaths):
        # use source paths
        secondaryfilelocation = []
        usesourcepaths = False
        if not mdffolder:
            usesourcepaths = True
        if usesourcepaths or showpaths:
            dbfileinfovec = None
            if importedfileinfo:
                importeddbfileinfo = [i for i in importedfileinfo if ieq(i.get('name'), sourcedbname)]
                if importeddbfileinfo:
                    dbfileinfovec = importeddbfileinfo[0]['fileInfo']
            else:
                filesearch = api('get', '/searchvms?environment=SQL&entityIds=%s' % thisrange['object']['id'])
                if filesearch is not None and filesearch.get('vms'):
                    sqlentity = filesearch['vms'][0]['vmDocument']['objectId']['entity'].get('sqlEntity', {})
                    if 'dbFileInfoVec' in sqlentity:
                        dbfileinfovec = sqlentity['dbFileInfoVec']
            if not dbfileinfovec:
                if not mdffolder:
                    print('    Skipping: File info not found, please use -mdffolder, -ldffolder, -ndffolder (or -importpaths)')
                    skippeddbs.append(sourcedbname)
                    continue
            if showpaths:
                if dbfileinfovec:
                    print('%-30s%-15s%s' % ('logicalName', 'Size (MiB)', 'fullPath'))
                    for datafile in dbfileinfovec:
                        sizemib = datafile.get('sizeBytes', 0) / (1024 * 1024)
                        print('%-30s%-15.2f%s' % (datafile.get('logicalName', ''), sizemib, datafile.get('fullPath', '')))
            mdffolderfound = False
            ldffolderfound = False
            if dbfileinfovec:
                for datafile in dbfileinfovec:
                    fullpath = datafile['fullPath']
                    path = fullpath[:fullpath.rfind('\\')]
                    if datafile.get('type') == 0:
                        if mdffolderfound is False:
                            mdffolder = path
                            mdffolderfound = True
                        else:
                            secondaryfilelocation.append({'filenamePattern': fullpath, 'directory': path})
                    if datafile.get('type') == 1:
                        if ldffolderfound is False:
                            ldffolder = path
                            ldffolderfound = True
                        else:
                            secondaryfilelocation.append({'filenamePattern': fullpath, 'directory': path})
        if not mdffolder or not ldffolder:
            print('    Skipping: File info not found, please use -mdffolder, -ldffolder, -ndffolder (or -importpaths)')
            skippeddbs.append(sourcedbname)
            continue
        targetconfig['dataFileDirectoryLocation'] = mdffolder
        targetconfig['logFileDirectoryLocation'] = ldffolder
        if len(secondaryfilelocation) > 0:
            targetconfig['secondaryDataFilesDirList'] = secondaryfilelocation
        elif ndffolders:
            ndfparams = []
            for key in ndffolders:
                ndfparams.append({'filenamePattern': key, 'directory': ndffolders[key]})
            targetconfig['secondaryDataFilesDirList'] = ndfparams

    # overwrite
    if not flatfilepath:
        if overwrite:
            targetconfig['overwritingPolicy'] = 'Overwrite'
        # no recovery
        if norecovery:
            targetconfig['withNoRecovery'] = True
        # keep CDC
        if keepcdc:
            targetconfig['keepCdc'] = True

    # add this param to recovery params
    if not showpaths and commit:
        recoveryparams['mssqlParams'][paramname].append(thisparam)
        dbsselected += 1

    # perform recovery group
    if dbsselected >= dbsperrecovery:
        recovery = api('post', 'data-protect/recoveries', recoveryparams, v=2)
        if recovery is None or 'id' not in recovery:
            exit(1)
        recoveryids.append(recovery['id'])
        recoveryparamnum += 1
        dbsselected = 0
        recoveryparams = newrecoveryparams(recoveryparamnum)

if dbg:
    with open('debug-recoveryParams.json', 'w') as f:
        json.dump(recoveryparams, f, indent=4)

### perform last recovery group (if any)
if len(recoveryparams['mssqlParams'][paramname]) > 0:
    recovery = api('post', 'data-protect/recoveries', recoveryparams, v=2)
    if recovery is None or 'id' not in recovery:
        exit(1)
    recoveryids.append(recovery['id'])

### wait for completion
failuresdetected = False
if (wait or progress) and len(recoveryids) > 0:
    finishedstates = ['Succeeded', 'Canceled', 'Failed', 'Warning', 'SucceededWithWarning']
    print('\nWaiting for recoveries to complete...\n')
    sleep(10)
    for recoveryid in recoveryids:
        thisrecovery = api('get', 'data-protect/recoveries/%s' % recoveryid, v=2)
        finisheddbs = []
        while thisrecovery is None or thisrecovery.get('status') not in finishedstates:
            if progress:
                dbstatus = 'unknown'
                while dbstatus not in finishedstates:
                    dbstatus = 'Succeeded'
                    childrecoveries = api('get', 'data-protect/recoveries?returnOnlyChildRecoveries=true&ids=%s' % recoveryid, v=2)
                    recoverieslist = childrecoveries.get('recoveries', []) if childrecoveries is not None else []
                    for childrecovery in sorted(recoverieslist, key=lambda r: r['mssqlParams'][paramname][0]['objectInfo']['name']):
                        dbname = childrecovery['mssqlParams'][paramname][0]['objectInfo']['name']
                        status = childrecovery.get('status')
                        if not status:
                            dbstatus = 'unknown'
                        if status not in finishedstates:
                            dbstatus = status
                        progresstaskid = childrecovery.get('progressTaskId')
                        progressmonitor = api('get', '/progressMonitors?taskPathVec=%s&excludeSubTasks=true&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0' % progresstaskid)
                        percentcomplete = None
                        if progressmonitor is not None:
                            try:
                                percentcomplete = progressmonitor['resultGroupVec'][0]['taskVec'][0]['progress']['percentFinished']
                            except Exception:
                                percentcomplete = None
                        if percentcomplete is not None and percentcomplete > 0:
                            if dbname not in finisheddbs:
                                print('\r%s: %d%%' % (dbname, round(percentcomplete)), end='')
                                if round(percentcomplete) == 100:
                                    print(' %s' % status)
                                    finisheddbs.append(dbname)
                    if dbstatus not in finishedstates:
                        sleep(sleeptime)
                print('')
            else:
                sleep(sleeptime)
            thisrecovery = api('get', 'data-protect/recoveries/%s' % recoveryid, v=2)
        childrecoveries = api('get', 'data-protect/recoveries?returnOnlyChildRecoveries=true&ids=%s' % recoveryid, v=2)
        recoverieslist = childrecoveries.get('recoveries', []) if childrecoveries is not None else []
        for childrecovery in sorted(recoverieslist, key=lambda r: r['mssqlParams'][paramname][0]['objectInfo']['name']):
            dbname = childrecovery['mssqlParams'][paramname][0]['objectInfo']['name']
            status = childrecovery.get('status')
            print('%s completed with status: %s' % (dbname, status))
            if childrecovery.get('messages'):
                print(childrecovery['messages'][0])
            if status != 'Succeeded':
                failuresdetected = True
    if failuresdetected or len(recoveryids) == 0:
        print('\nFailures Detected\n')
        if len(skippeddbs) > 0:
            print('Skipped DBs (missing file paths):\n\n%s\n' % '\n'.join(skippeddbs))
        exit(1)
    else:
        print('\nRestores Completed Successfully\n')
        if len(skippeddbs) > 0:
            print('Skipped DBs (missing file paths):\n\n%s\n' % '\n'.join(skippeddbs))
            exit(1)
        exit(0)
elif len(recoveryids) > 0:
    print('\nPerforming recoveries...\n')
else:
    print('')

if not commit:
    print('Exiting without recovering. Please use the -commit switch to perform the recoveries')
    exit(0)

if len(skippeddbs) > 0:
    print('Skipped DBs (missing file paths):\n\n%s\n' % '\n'.join(skippeddbs))
    exit(1)

exit(0)
