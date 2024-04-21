#!/usr/bin/env python
"""Storage Report for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str)
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
useApiKey = args.useApiKey

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

print('Collecting report data...')

cluster = api('get', 'cluster')
remotes = api('get', 'remoteClusters')
jobs = api('get', 'protectionJobs')
title = 'Storage Report for %s' % cluster['name']

now = datetime.now()
datestring = now.strftime("%Y-%m-%d")
htmlfileName = '%s/storageReport-%s-%s.html' % (folder, cluster['name'], datestring)
csvfileName = '%s/storageReport-%s-%s.csv' % (folder, cluster['name'], datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write("Job/View Name,Environment,Local/Replicated,Source Cluster,GiB Logical,GiB Ingested,GiB Consumed,Dedup Ratio,Compression,Reduction\n")

html = '''<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F1F1F1;
        }

        td,
        th {
            text-align: left;
            padding: 6px;
        }

        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>

    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALQAAAAaCAYAAAAe23
            asAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAXEgAAFxIBZ5/SUgAAAVlpVFh0WE1MOmNvbS5hZG9i
            ZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9Il
            hNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9y
            Zy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZG
            Y6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90
            aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW
            9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K
            TMInWQAAF3RJREFUeAHdnAmUlcWVx7/v7d10gwu4x4VxGcUlMYoaTQLS0GLUODO2TsYxaDxBBT
            GuMS6ZPM9JYjSajDFAglscHbd3NC5HUewWFPctTFwSzVGMioMgUZZe3vrN71/vu4/Xj/foB84o
            Zy7eV1W3bt26detf9dW3tL63LiURZUNxMhaLjSc/Ad4P/gK8HRwPgmCp7/vvkn8BfrBQKCwgFc
            XhIlxSoQFJpwAHqqePr5B8DXt7Y1f2W2G1/5jyW6QvFIvFBaTvwSL5mIdr+4giU98j4/H4P5FK
            zy+VSstofyd56fuw65e0HpmNrUIbKsex8R427iavthG4hN8T8Xln6nKRSET9IG6aAtpEaFPA7v
            20WgkP8m3GQ5OT1x45183F1BePbo2u7t/XK/q7ojfC9yPSbUh+pBQERS+G/j2zOue9FwQerjp1
            +e9Ho9F/pPsdybs45vN5je1Dp0H8qe+ifnPKOVjj/TSkoT6YzWbfSqVSoxlvJ8ZicJH5TRHHew
            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" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'''

html += title
html += '''</span>
<span style="font-size:1em; text-align: right; padding-top: 8px; padding-right: 2px; float: right;">'''
html += datestring
html += '''</span>
</p>
<table>
<tr>
    <th>Job/View Name</th>
    <th>Environment</th>
    <th>Local/Replicated</th>
    <th>Source Cluster</th>
    <th>GiB Logical</th>
    <th>GiB Ingested</th>
    <th>GiB Consumed</th>
    <th>Dedup Ratio</th>
    <th>Compression</th>
    <th>Reduction</th>
</tr>'''


def processStats(stats, name, environment, location):
    if location == 'Replicated':
        jobId = stats['id']
        job = [j for j in jobs if j['id'] == jobId]
        if job is not None and len(job) > 0:
            jobClusterId = job[0]['policyId'].split(':')[0]
            remote = [r for r in remotes if int(r['clusterId']) == int(jobClusterId)]
            # display(remote)

            if remote is not None and len(remote) > 0:
                sourcecluster = remote[0]['name']
            else:
                sourcecluster = 'UNKNOWN'
        else:
            sourcecluster = 'UNKNOWN'
    else:
        sourcecluster = cluster['name']
    logicalBytes = stats['stats'].get('totalLogicalUsageBytes', 0)
    dataIn = stats['stats'].get('dataInBytes', 0)
    dataInAfterDedup = stats['stats'].get('dataInBytesAfterDedup', 0)
    dataWritten = stats['stats'].get('dataWrittenBytes', 0)
    consumedBytes = stats['stats'].get('storageConsumedBytes', 0)
    if dataInAfterDedup > 0 and dataWritten > 0:
        dedup = round(float(dataIn) / dataInAfterDedup, 1)
        compression = round(float(dataInAfterDedup) / dataWritten, 1)
    else:
        dedup = 0
        compression = 0
    if consumedBytes > 0:
        reduction = round(float(dataIn) / dataWritten, 1)
    else:
        reduction = 0
    consumption = round(float(consumedBytes) / (1024 * 1024 * 1024), 1)
    logical = round(float(logicalBytes) / (1024 * 1024 * 1024), 1)
    dataInGiB = round(float(dataIn) / (1024 * 1024 * 1024), 1)
    print('%30s: %11s %s' % (name, consumption, 'GiB'))
    csv.write('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (name, environment, location, sourcecluster, logical, dataInGiB, consumption, dedup, compression, reduction))
    return '''<tr>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    </tr>''' % (name, environment, location, sourcecluster, logical, dataInGiB, consumption, dedup, compression, reduction)


jobs = api('get', 'protectionJobs?allUnderHierarchy=true')

msecsBeforeCurrentTimeToCompare = 7 * 24 * 60 * 60 * 1000

cookie = ''
viewJobStats = {'statsList': []}
while True:
    theseStats = api('get', 'stats/consumers?consumerType=kViewProtectionRuns&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (msecsBeforeCurrentTimeToCompare, cookie))
    if 'statsList' in theseStats:
        viewJobStats['statsList'] = viewJobStats['statsList'] + theseStats['statsList']
    if 'cookie' in theseStats:
        cookie = theseStats['cookie']
    else:
        cookie = ''
    if cookie == '':
        break

print("\n  Local ProtectionJobs...")

cookie = ''
localStats = {'statsList': []}
while True:
    theseStats = api('get', 'stats/consumers?consumerType=kProtectionRuns&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (msecsBeforeCurrentTimeToCompare, cookie))
    if 'statsList' in theseStats:
        localStats['statsList'] = localStats['statsList'] + theseStats['statsList']
    if 'cookie' in theseStats:
        cookie = theseStats['cookie']
    else:
        cookie = ''
    if cookie == '':
        break
localStats['statsList'] = localStats['statsList'] + viewJobStats['statsList']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if job['policyId'].split(':')[0] == str(cluster['id']):
        stats = [s for s in localStats['statsList'] if s['id'] == job['id'] or s['name'].lower() == job['name'].lower()]
        for stat in stats:
            html += processStats(stat, job['name'], job['environment'][1:], 'Local')

print("\n  Replicated ProtectionJobs...")

cookie = ''
replicaStats = {'statsList': []}
while True:
    replicaStats = api('get', 'stats/consumers?consumerType=kReplicationRuns&msecsBeforeCurrentTimeToCompare=%s&cookie=%s' % (msecsBeforeCurrentTimeToCompare, cookie))
    if 'statsList' in theseStats:
        replicaStats['statsList'] = replicaStats['statsList'] + theseStats['statsList']
    if 'cookie' in theseStats:
        cookie = theseStats['cookie']
    else:
        cookie = ''
    if cookie == '':
        break
replicaStats['statsList'] = replicaStats['statsList'] + viewJobStats['statsList']

for job in sorted(jobs, key=lambda job: job['name'].lower()):
    if job['policyId'].split(':')[0] != str(cluster['id']):
        stats = [s for s in replicaStats['statsList'] if s['id'] == job['id'] or s['name'].lower() == job['name'].lower()]
        for stat in stats:
            html += processStats(stat, job['name'], job['environment'][1:], 'Replicated')

print("\n  Unprotected Views...")
views = api('get', 'file-services/views?includeTenants=true&includeStats=false&includeProtectionGroups=true', v=2)
if 'views' in views and len(views['views']) > 0:
    for view in sorted([v for v in views['views'] if 'viewProtection' not in v], key=lambda view: view['name'].lower()):
        stats = api('get', 'stats/consumers?consumerType=kViews&consumerIdList=%s' % view['viewId'])
        if 'statsList' in stats and stats['statsList'] is not None:
            for stat in stats['statsList']:
                html += processStats(stat, view['name'], 'View', 'Local')

html += '''</table>
</div>
</body>
</html>
'''

print('\nsaving report as %s' % htmlfileName)
print('             and %s\n' % csvfileName)

f = codecs.open(htmlfileName, 'w', 'utf-8')
f.write(html)
f.close()
