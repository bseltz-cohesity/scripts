#!/usr/bin/env python
"""backed up files list for python"""

# import pyhesity wrapper module
from pyhesity import *
import os
import codecs
import argparse
from time import sleep

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-n', '--numruns', type=int, default=1000)
parser.add_argument('-y', '--days', type=int, default=7)
parser.add_argument('-s', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-o', '--outputpath', type=str, default='.')
parser.add_argument('-f', '--outputfile', type=str, default='physicalBackupPathsHistoryReport.csv')
parser.add_argument('-r', '--retries', type=int, default=30)

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
numruns = args.numruns
days = args.days
servernames = args.servername         # name of server to protect
serverlist = args.serverlist          # file with server names
outputpath = args.outputpath
outputfile = args.outputfile
retries = args.retries

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


servernames = gatherList(servernames, serverlist, name='servers', required=False)

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

daysBackUsecs = timeAgo(days, "days")

outfile = os.path.join(outputpath, outputfile)
f = codecs.open(outfile, 'w')
f.write('"Cluster","Protection Group","Start Time","End Time","Status","Server","Directive File","Selected Path","Confirmed"\n')


def getCluster(thiscluster):

    gotcluster = False
    while gotcluster is False:
        x = 0
        cluster = api('get', 'cluster')
        if cluster is None or 'name' not in cluster or cluster['name'] is None:
            print('waiting for cluster connection...')
            sleep(30)
            x += 1
            if x >= retries:
                print('failed to connect to cluster %s' % thiscluster)
                return None
        else:
            print('\n%s' % cluster['name'])
            try:
                jobs = api('get', 'data-protect/protection-groups?environments=kPhysical&isActive=true&isDeleted=false&includeTenants=true', v=2)

                if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
                    for job in sorted(jobs['protectionGroups'], key=lambda job: job['name'].lower()):
                        if job['physicalParams']['protectionType'] == 'kFile':
                            v1JobId = job['id'].split(':')[2]
                            thisJob = api('get', 'protectionJobs/%s' % v1JobId)
                            startTimeUsecs = daysBackUsecs
                            confirmStartTimeUsecs = startTimeUsecs
                            if thisJob is not None and 'modificationTimeUsecs' in thisJob and thisJob['modificationTimeUsecs'] is not None and thisJob['modificationTimeUsecs'] > startTimeUsecs:
                                confirmStartTimeUsecs = thisJob['modificationTimeUsecs']
                                print('  %s:  *** modified on %s ***' % (job['name'], usecsToDate(thisJob['modificationTimeUsecs'])))
                            else:
                                print('  %s' % job['name'])
                            runs = api('get', 'data-protect/protection-groups/%s/runs?numRuns=%s&includeTenants=true&startTimeUsecs=%s&includeObjectDetails=true' % (job['id'], numruns, startTimeUsecs), v=2)
                            countedRuns = 0
                            if len(runs['runs']) > 0:
                                for run in runs['runs']:
                                    countedRuns += 1
                                    confirmed = True
                                    if run['localBackupInfo']['startTimeUsecs'] < confirmStartTimeUsecs:
                                        confirmed = False
                                    if 'isLocalSnapshotsDeleted' not in run or run['isLocalSnapshotsDeleted'] is not True:
                                        runStartTime = usecsToDate(run['localBackupInfo']['startTimeUsecs'])
                                        runEndTime = '-'
                                        if 'endTimeUsecs' in run['localBackupInfo']:
                                            runEndTime = usecsToDate(run['localBackupInfo']['endTimeUsecs'])
                                        if 'objects' in job['physicalParams']['fileProtectionTypeParams'] and job['physicalParams']['fileProtectionTypeParams']['objects'] is not None and len(job['physicalParams']['fileProtectionTypeParams']['objects']) > 0:
                                            for obj in sorted(job['physicalParams']['fileProtectionTypeParams']['objects'], key=lambda obj: obj['name'].lower()):
                                                if len(servernames) == 0 or obj['name'].lower() in [s.lower() for s in servernames]:
                                                    status = run['localBackupInfo']['status']
                                                    runobject = [o for o in run['objects'] if o['object']['id'] == obj['id']]
                                                    if runobject is not None and len(runobject) > 0:
                                                        status = runobject[0]['localSnapshotInfo']['snapshotInfo']['status'][1:]
                                                        usesDirective = False
                                                        if 'metadataFilePath' in obj and obj['metadataFilePath'] is not None:
                                                            usesDirective = True
                                                            f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], runStartTime, runEndTime, status, obj['name'], usesDirective, obj['metadataFilePath'], confirmed))
                                                        elif 'filePaths' in obj and obj['filePaths'] is not None and len(obj['filePaths']) > 0:
                                                            for filepath in sorted(obj['filePaths'], key=lambda filepath: filepath['includedPath'].lower()):
                                                                f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], runStartTime, runEndTime, status, obj['name'], usesDirective, filepath['includedPath'], confirmed))
                                                        else:
                                                            f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], runStartTime, runEndTime, status, obj['name'], usesDirective, 'unknown', confirmed))
                                                            print('******* debug output ********')
                                                            display(obj)
                                                            print('*****************************')
                                                    else:
                                                        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], runStartTime, runEndTime, status, obj['name'], 'unknown', 'unknown', confirmed))
                            if countedRuns == 0:
                                print('      ***** no runs reported since modification date *****')
                gotcluster = True
            except Exception:
                print('failed to get data from cluster %s' % thiscluster)

for vip in vips:

    # authentication =========================================================
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

    # exit if not authenticated
    if apiconnected() is False:
        print('authentication failed')
        continue

    # if connected to helios or mcm, select access cluster
    if mcm or vip.lower() == 'helios.cohesity.com':
        if clusternames is None or len(clusternames) == 0:
            clusternames = [c['name'] for c in heliosClusters()]
        for clustername in clusternames:
            heliosCluster(clustername)
            if LAST_API_ERROR() != 'OK':
                continue
            getCluster(clustername)
    else:
        getCluster(vip)

f.close()
print('\nOutput saved to %s\n' % outfile)

f.close()
