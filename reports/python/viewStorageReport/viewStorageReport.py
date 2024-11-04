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
parser.add_argument('-y', '--growthdays', type=int, default=7)
parser.add_argument('-x', '--units', type=str, choices=['MiB', 'GiB', 'mib', 'gib'], default='GiB')
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
growthdays = args.growthdays
units = args.units

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

now = datetime.now()
nowUsecs = dateToUsecs(now.strftime("%Y-%m-%d %H:%M:%S"))
growthdaysusecs = timeAgo(growthdays, 'days')
msecsBeforeCurrentTimeToCompare = growthdays * 24 * 60 * 60 * 1000
datestring = now.strftime("%Y-%m-%d")
csvfileName = '%s/viewStorageReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"View Name","Created Date","Protection Group","Tenant","Storage Domain","%s Logical","%s Written","%s Written plus Resiliency","Reduction Ratio","%s Written Last %s Days","%s Archived","%s per Archive Target"\n' % (units, units, units, units, growthdays, units, units))

vaults = api('get', 'vaults')
if vaults is not None and len(vaults) > 0:
    nowMsecs = int((dateToUsecs()) / 1000)
    weekAgoMsecs = nowMsecs - 86400000
    cloudStatURL = 'reports/dataTransferToVaults?endTimeMsecs=%s&startTimeMsecs=%s' % (nowMsecs, weekAgoMsecs)
    for vault in vaults:
        cloudStatURL += '&vaultIds=%s' % vault['id']
    cloudStats = api('get', cloudStatURL)

print('')

# views
views = api('get', 'file-services/views?maxCount=2000&includeTenants=true&includeStats=true&includeProtectionGroups=true', v=2)
if 'views' in views and views['views'] is not None and len(views['views']) > 0:
    stats = api('get', 'stats/consumers?msecsBeforeCurrentTimeToCompare=%s&consumerType=kViews' % (growthdays * 86400000))
    # build total job FE sizes
    viewJobStats = {}
    for view in views['views']:
        try:
            jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
        except Exception:
            jobName = '-'
        if jobName not in viewJobStats:
            viewJobStats[jobName] = 0
        viewJobStats[jobName] += view['stats']['dataUsageStats']['totalLogicalUsageBytes']

    for view in views['views']:
        created = usecsToDate(uedate=(view['createTimeMsecs'] * 1000), fmt='%Y-%m-%d')
        try:
            jobName = view['viewProtection']['protectionGroups'][-1]['groupName']
        except Exception:
            jobName = '-'
        sourceName = view['storageDomainName']
        viewName = view['name']
        print(viewName)
        tenant = ''
        if 'tenantId' in view and view['tenantId'] is not None:
            tenant = view['tenantId'][:-1]
        dataIn = 0
        dataInAfterDedup = 0
        jobWritten = 0
        consumption = 0
        objWeight = 1
        try:
            objFESize = round(view['stats']['dataUsageStats']['totalLogicalUsageBytes'] / multiplier, 1)
            dataIn = view['stats']['dataUsageStats'].get('dataInBytes', 0)
            dataInAfterDedup = view['stats']['dataUsageStats'].get('dataInBytesAfterDedup', 0)
            jobWritten = view['stats']['dataUsageStats'].get('dataWrittenBytes', 0)
            consumption = view['stats']['dataUsageStats'].get('localTotalPhysicalUsageBytes', 0)
            if jobName != '-':
                objWeight = view['stats']['dataUsageStats']['totalLogicalUsageBytes'] / viewJobStats[jobName]
        except Exception:
            pass
        if dataInAfterDedup > 0 and jobWritten > 0:
            dedup = round(float(dataIn) / dataInAfterDedup, 1)
            compression = round(float(dataInAfterDedup) / jobWritten, 1)
            jobReduction = round((float(dataIn) / dataInAfterDedup) * (float(dataInAfterDedup) / jobWritten), 1)
        else:
            jobReduction = 1
        try:
            stat = [s for s in stats['statsList'] if s['name'] == viewName]
            if stat is not None and len(stat) > 0:
                if 'storageConsumedBytesPrev' not in stat[0]['stats']:
                    stat[0]['stats']['storageConsumedBytesPrev'] = 0
                objGrowth = round((stat[0]['stats']['storageConsumedBytes'] - stat[0]['stats']['storageConsumedBytesPrev']) / multiplier, 1)
        except Exception:
            objGrowth = 0
        # archive Stats
        totalArchived = 0
        vaultStats = ''
        if cloudStats is not None and 'dataTransferSummary' in cloudStats and len(cloudStats['dataTransferSummary']) > 0:
            for vaultSummary in cloudStats['dataTransferSummary']:
                if vaultSummary is not None and 'dataTransferPerProtectionJob' in vaultSummary and len(vaultSummary['dataTransferPerProtectionJob']) > 0:
                    for cloudJob in vaultSummary['dataTransferPerProtectionJob']:
                        if cloudJob['protectionJobName'] == jobName:
                            if cloudJob['storageConsumed'] > 0:
                                totalArchived += (objWeight * cloudJob['storageConsumed'])
                                vaultStats += '[%s]%s ' % (vaultSummary['vaultName'], round((objWeight * cloudJob['storageConsumed']) / multiplier, 1))
        totalArchived = round(totalArchived / multiplier, 1)
        csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (viewName, created, jobName, tenant, sourceName, objFESize, round(jobWritten / multiplier, 1), round(consumption / multiplier, 1), jobReduction, objGrowth, totalArchived, vaultStats))
csv.close()
print('\nOutput saved to %s\n' % csvfileName)
