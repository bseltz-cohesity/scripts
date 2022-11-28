#!/usr/bin/env python
"""Create a Cohesity NFS View Using python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)  # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-n', '--numruns', type=int, default=100)
parser.add_argument('-b', '--daysback', type=int, default=31)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')  # units

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
units = args.units
numruns = args.numruns
daysback = args.daysback

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

# authenticate
apiauth(vip, username, domain)

# output file
cluster = api('get', 'cluster')
now = datetime.now()
midnight = datetime.combine(now, datetime.min.time())
midnightusecs = dateToUsecs(midnight.strftime("%Y-%m-%d %H:%M:%S"))
daysbackusecs = midnightusecs - (daysback * 86400000000)
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
datestring = now.strftime("%Y-%m-%d")
csvfileName = 'dataPerObject-%s-%s.csv' % (cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write("Job Name,Object Name,Logical Size,Read Last 24 Hours (%s),Read Last %s Days (%s),Written Last 24 Hours (%s),Written Last %s Days (%s),Days Gathered\n" % (units, daysback, units, units, daysback, units))

jobs = [j for j in api('get', 'protectionJobs?allUnderHierarchy=true') if ('isActive' not in j or j['isActive'] is not False) and ('isDeleted' not in j or j['isDeleted'] is not True)]

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    print(job['name'])
    stats = {}
    endUsecs = midnightusecs
    while 1:
        runs = [r for r in api('get', 'protectionRuns?jobId=%s&numRuns=%s&endTimeUsecs=%s&excludeNonRestoreableRuns=true' % (job['id'], numruns, endUsecs)) if r['backupRun']['stats']['endTimeUsecs'] < endUsecs]
        if len(runs) > 0:
            endUsecs = runs[-1]['backupRun']['stats']['startTimeUsecs']
        else:
            break
        for run in runs:
            for source in run['backupRun']['sourceBackupStatus']:
                sourceName = source['source']['name']
                if sourceName not in stats:
                    stats[sourceName] = []
                if run['backupRun']['stats']['startTimeUsecs'] > daysbackusecs:
                    stats[sourceName].append({
                        'startTimeUsecs': run['backupRun']['stats']['startTimeUsecs'],
                        'dataRead': source['stats'].get('totalBytesReadFromSource', 0),
                        'dataWritten': source['stats'].get('totalPhysicalBackupSizeBytes', 0),
                        'logicalSize': source['stats'].get('totalLogicalBackupSizeBytes', 0)
                    })
    for sourceName in stats:
        if len(stats[sourceName]) > 0:
            print("  %s" % sourceName)

            # logical size
            logicalSize = stats[sourceName][0]['logicalSize']

            # last 24 hours
            last24Hours = timeAgo(1, 'day')
            last24HourStats = [s for s in stats[sourceName] if s['startTimeUsecs'] > last24Hours]
            last24HoursDataRead = 0
            last24HoursDataWritten = 0
            for stat in last24HourStats:
                last24HoursDataRead += stat['dataRead']
                last24HoursDataWritten += stat['dataWritten']

            # last X days
            lastXDaysStats = [s for s in stats[sourceName] if s['startTimeUsecs'] > daysbackusecs]
            lastXDaysDataRead = 0
            lastXDaysDataWritten = 0
            for stat in lastXDaysStats:
                lastXDaysDataRead += stat['dataRead']
                lastXDaysDataWritten += stat['dataWritten']

            # number of days gathered
            oldestStat = datetime.combine(datetime.strptime(usecsToDate(stats[sourceName][-1]['startTimeUsecs']), '%Y-%m-%d %H:%M:%S'), datetime.min.time())
            numDays = (midnight - oldestStat).days
            csv.write('%s,%s,"%s","%s","%s","%s","%s",%s\n' % (job['name'], sourceName, int(round(logicalSize / multiplier, 0)), int(round(last24HoursDataRead / multiplier, 0)), int(round(lastXDaysDataRead / multiplier, 0)), int(round(last24HoursDataWritten / multiplier, 0)), int(round(lastXDaysDataWritten / multiplier, 0)), numDays))

csv.close()
print('Output saved to %s' % csvfileName)
