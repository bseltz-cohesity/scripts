#!/usr/bin/env python
"""Storage Per Object Report for Python"""

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
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-n', '--pagesize', type=int, default=1000)
parser.add_argument('-y', '--days', type=int, default=30)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
parser.add_argument('-s', '--skipdeleted', action='store_true')

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
folder = args.outfolder
pagesize = args.pagesize
days = args.days
units = args.units
skipdeleted = args.skipdeleted

multiplier = 1024 * 1024 * 1024
if units.lower() == 'mib':
    multiplier = 1024 * 1024

if units == 'mib':
    units = 'MiB'
if units == 'gib':
    units = 'GiB'

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

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


cluster = api('get', 'cluster')
if cluster['clusterSoftwareVersion'] < '6.6':
    print('this script requires Cohesity 6.6 or later')
    exit(1)

print('Collecting report data...')

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
daysAgoUsecs = timeAgo(days, 'days')
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/dataReadPerVMReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Job Name","Start Time","Source Name","Object Name","%s Provisioned","%s Used","%s Read","%s Read (adjuested)"\n' % (units, units, units, units))

if skipdeleted:
    jobs = sorted(api('get', 'protectionJobs?environments=kVMware&allUnderHierarchy=true&isActive=true&isDeleted=false'), key=lambda job: job['name'].lower())
else:
    jobs = sorted(api('get', 'protectionJobs?environments=kVMware&allUnderHierarchy=true&isActive=true'), key=lambda job: job['name'].lower())

for job in jobs:
    tenantTail = ''
    if 'tenantId' in job:
        tenantTail = '&tenantId=%s' % job['tenantId']
    print(job['name'])
    startfrom = 0
    ro = api('get', '/searchvms?environments=kVMware&allUnderHierarchy=true&jobIds=%s&size=%s&from=%s%s' % (job['id'], pagesize, startfrom, tenantTail))
    if len(ro) > 0:
        while True:
            if 'vms' in ro:
                ro['vms'].sort(key=lambda obj: obj['vmDocument']['objectName'])
                for vm in ro['vms']:
                    doc = vm['vmDocument']
                    vmName = doc['objectName']
                    print('    %s' % vmName)
                    vCenter = doc['registeredSource']['displayName']
                    versions = [v for v in doc['versions'] if v['snapshotTimestampUsecs'] >= daysAgoUsecs]
                    if versions is not None and len(versions) > 0:
                        used = doc['objectId']['entity']['vmwareEntity']['frontEndSizeInfo']['sizeBytes']
                        used = round(used / multiplier, 1)
                        for version in versions:
                            startTime = usecsToDate(version['instanceId']['jobStartTimeUsecs'])
                            provisioned = version['logicalSizeBytes']
                            provisioned = round(provisioned / multiplier, 1)
                            dataRead = version['deltaSizeBytes']
                            if dataRead > used:
                                adjustedRead = dataRead - (provisioned - used)
                                if adjustedRead < 0:
                                    adjustedRead = used
                            else:
                                adjustedRead = dataRead
                            dataRead = round(dataRead / multiplier, 1)
                            adjustedRead = round(adjustedRead / multiplier, 1)
                            csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], startTime, vCenter, vmName, provisioned, used, dataRead, adjustedRead))
            if ro['count'] > (pagesize + startfrom):
                startfrom += pagesize
                ro = api('get', '/searchvms?environments=kVMware&allUnderHierarchy=true&jobIds=%s&size=%s&from=%s%s' % (job['id'], pagesize, startfrom, tenantTail))
            else:
                break

csv.close()
print('\nOutput saved to %s\n' % csvfileName)
