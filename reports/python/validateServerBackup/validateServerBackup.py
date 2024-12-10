#!/usr/bin/env python
"""Backup Strike Report v3.0"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import os
import codecs
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# command line arguments
import argparse
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
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str)
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-wh', '--warninghours', type=int, default=48)
parser.add_argument('-p', '--pagesize', type=int, default=1000)
parser.add_argument('-ms', '--mailserver', type=str)
parser.add_argument('-mp', '--mailport', type=int, default=25)
parser.add_argument('-to', '--sendto', action='append', type=str)
parser.add_argument('-fr', '--sendfrom', type=str)

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
emailmfacode = args.emailmfacode
outfolder = args.outfolder
servernames = args.servername
serverlist = args.serverlist
pagesize = args.pagesize
warninghours = args.warninghours
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

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

objects = gatherList(servernames, serverlist, name='jobs', required=False)

title = 'Backup Validation Report'
now = datetime.now()
nowUsecs = dateToUsecs()
warningUsecs = nowUsecs - (warninghours * 3600000000)
date = now.strftime("%Y-%m-%d")
htmlfileName = os.path.join(outfolder, 'serverValidationReport-%s.html' % date)

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
            width: 20%;
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
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
            WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
            EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
            tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
            WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
            7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
            FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
            ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
            zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
            Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
            +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
            lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
            t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
            Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
            gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
            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
            8LK0YAAAAASUVORK5CYII=" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'''

html += title
html += '''</span>
<span style="font-size:1em; text-align: right; padding-right: 2px; float: right;">'''
html += date
html += '''</span>
</p>
<table>
<tr>
    <th>ClusterName</th>
    <th>ObjectName</th>
    <th>ObjectType</th>
    <th>JobName</th>
    <th>RunDate</th>
    <th>Validated</th>
</tr>'''

volumeTypes = [1, 6, 8, 12, 28, 29, 36]
finishedStates = ['kCanceled', 'kSuccess', 'kFailure', 'kWarning']
entityTypes="entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware"

def validateServer(object, vm):
    global runs
    global html
    global cluster
    doc = vm['vmDocument']
    version = doc['versions'][0]
    jobId = doc['objectId']['jobId']
    jobStartedTimeUsecs = version['instanceId']['jobStartTimeUsecs']
    jobName = doc['jobName']
    backupType = doc['backupType']
    lastRecoveryPoint = version['instanceId']['jobStartTimeUsecs']
    if '%s-%s' % (jobId, jobStartedTimeUsecs) not in runs.keys():
        run = api('get', 'protectionRuns?jobId=%s&startedTimeUsecs=%s' % (jobId, jobStartedTimeUsecs))
        runs['%s-%s' % (jobId, jobStartedTimeUsecs)] = run
    else:
        run = runs['%s-%s' % (jobId, jobStartedTimeUsecs)]
    if run[0]['backupRun']['snapshotsDeleted'] is True:
        return
    environment = run[0]['backupRun']['environment']
    lastRunUsecs = run[0]['backupRun']['stats']['startTimeUsecs']
    lastStatus = run[0]['backupRun']['status']
    if 'sourceBackupStatus' in run[0]['backupRun']:
        thissource = [s for s in run[0]['backupRun']['sourceBackupStatus'] if s['source']['name'].lower() == object.lower()]
        if len(thissource) > 0:
            thissource = thissource[0]
            lastStatus = thissource['status']
    # get latest recovery point dirlist
    readableBackup = False
    if 'attemptNum' not in version['instanceId']:
        attemptNum = 0
    else:
        attemptNum = version['instanceId']['attemptNum']
    instance = "attemptNum=%s&clusterId=%s&clusterIncarnationId=%s&entityId=%s&jobId=%s&jobInstanceId=%s&jobStartTimeUsecs=%s&jobUidObjectId=%s" % (
            attemptNum,
            doc['objectId']['jobUid']['clusterId'],
            doc['objectId']['jobUid']['clusterIncarnationId'],
            doc['objectId']['entity']['id'],
            doc['objectId']['jobId'],
            version['instanceId']['jobInstanceId'],
            version['instanceId']['jobStartTimeUsecs'],
            doc['objectId']['jobUid']['objectId'])
    if backupType in volumeTypes:
        volumeList = api('get', '/vm/volumeInfo?%s&statFileEntries=false' % instance)
        if 'volumeInfos' in volumeList:
            readableBackup = True             
    else:
        dirList = api('get', '/vm/directoryList?%s&dirPath=%%2F&statFileEntries=false' % instance)
        if 'entries' in dirList:
            readableBackup = True
    lastBackupReadable = ((lastRecoveryPoint == lastRunUsecs) and readableBackup)
    if lastStatus == 'kFailure' or False == lastBackupReadable:
        html += "<tr style='color:BA3415;'>"
    elif lastRecoveryPoint < warningUsecs:
        html += "<tr style='color:5c0e6b;'>"
    else:
        html += "<tr>"
    html += '''<td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    <td>%s</td>
    </tr>''' % (cluster['name'], object, environment[1:], jobName, usecsToDate(lastRunUsecs), lastBackupReadable)
    print("%s  %s  %s  %s  %s" % (
                object,
                jobName,
                usecsToDate(lastRunUsecs),
                lastStatus[1:],
                lastBackupReadable))

def getObjects():
    
    if len(objects) == 0:
        startfrom = 0
        search = api('get', '/searchvms?%s&size=%s&from=%s&vmName=*' % (entityTypes, pagesize, startfrom))
        if search is not None and len(search) > 0:
            while(True):
                for vm in sorted(search['vms'], key=lambda result: result['vmDocument']['objectName'].lower()):
                    object = vm['vmDocument']['objectName']
                    validateServer(object, vm)
                if search['count'] > (pagesize + startfrom):
                    startfrom += pagesize
                    search = api('get', '/searchvms?%s&size=%s&from=%s&vmName=*' % (entityTypes, pagesize, startfrom))
                else:
                    break
    else:
        for object in objects:
            search = api('get', '/searchvms?%s&vmName=%s' % (entityTypes, object))
            if search is None or 'vms' not in search or search['vms'] is None or len(search['vms']) == 0:
                continue
            else:
                # narrow search to exact name match
                search['vms'] = [v for v in search['vms'] if v['vmDocument']['objectName'].lower() == object.lower()]
                if len(search['vms']) == 0:
                    continue
                else:
                    # narrow search to latest available recovery point
                    vm = sorted(search['vms'], key=lambda result: result['vmDocument']['versions'][0]['snapshotTimestampUsecs'], reverse=True)[0]
                    validateServer(object, vm)

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

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
            runs = {}
            cluster = api('get','cluster')
            getObjects()
    else:
        runs = {}
        cluster = api('get','cluster')
        getObjects()

html += '''</table>                
</div>
</body>
</html>'''
f = codecs.open(htmlfileName, 'w', 'utf-8')
f.write(html)
f.close()
print('\nOutput saved to %s\n' % htmlfileName)

if mailserver is not None and sendto is not None and sendfrom is not None:
    msg = MIMEMultipart()
    msg['From'] = sendfrom
    msg['To'] = ', '.join(sendto)
    msg['Subject'] = "Server Backup Validation Report"
    body = html
    msg.attach(MIMEText(body, 'html'))
    filename = htmlfileName
    attachment = open(htmlfileName, "rb")
    part = MIMEBase('application', 'octet-stream')
    part.set_payload((attachment).read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', "attachment; filename= %s" % filename)
    msg.attach(part)
    smtp = smtplib.SMTP(mailserver, mailport)
    smtp.sendmail(sendfrom, sendto, msg.as_string())
    print('Sending email report to %s\n' % ', '.join(sendto))
