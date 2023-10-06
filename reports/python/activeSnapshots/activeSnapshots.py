#!/usr/bin/env python
"""Active Snapshots Report for python"""

### import pyhesity wrapper module
from pyhesity import *
import codecs
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

### command line arguments
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
parser.add_argument('-n', '--pagesize', type=int, default=1000)
parser.add_argument('-y', '--days', type=int, default=None)
parser.add_argument('-e', '--environment', type=str, action='append')
parser.add_argument('-x', '--excludeenvironment', type=str, action='append')
parser.add_argument('-o', '--outputpath', type=str, default='.')
parser.add_argument('-l', '--localonly', action='store_true')
parser.add_argument('-ms', '--mailserver', type=str)
parser.add_argument('-mp', '--mailport', type=int, default=25)
parser.add_argument('-to', '--sendto', action='append', type=str)
parser.add_argument('-fr', '--sendfrom', type=str)

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
pagesize = args.pagesize
days = args.days
environment = args.environment
excludeenvironment = args.excludeenvironment
outputpath = args.outputpath
localonly = args.localonly
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

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

environments = ['Unknown', 'VMware', 'HyperV', 'SQL', 'View', 'Puppeteer', 'Physical',
                'Pure', 'Azure', 'Netapp', 'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS', 'Oracle', 'GCP', 'FlashBlade',
                'AWSNative', 'VCD', 'O365', 'O365Outlook', 'HyperFlex', 'GCPNative', 'AzureNative',
                'AD', 'AWSSnapshotManager', 'GPFS', 'RDSSnapshotManager', 'Unknown', 'Kubernetes',
                'Nimble', 'AzureSnapshotManager', 'Elastifile', 'Cassandra', 'MongoDB', 'HBase',
                'Hive', 'Hdfs', 'Couchbase', 'AuroraSnapshotManager', 'O365PublicFolders', 'UDA',
                'O365Teams', 'O365Group', 'O365Exchange', 'O365OneDrive', 'O365Sharepoint', 'Sfdc',
                'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown']

cluster = api('get', 'cluster')
outfileName = os.path.join(outputpath, 'activeSnapshots-%s.csv' % cluster['name'])

if days is not None:
    daysBackUsecs = timeAgo(days, 'days')

f = codecs.open(outfileName, 'w', 'utf-8')
f.write('"Cluster Name","Job Name","Job Type","Source Name","Object Name","SQL AAG Name","Active Snapshots","Oldest Snapshot","Newest Snapshot"\n')

etail = ''
if environment is not None and len(environment) > 0:
    etail = '&entityTypes=%s' % ','.join(environment)

if excludeenvironment is not None and len(excludeenvironment) > 0:
    excludeenvironment = [e.lower() for e in excludeenvironment]

### find recoverable objects
jobs = sorted(api('get', 'protectionJobs?allUnderHierarchy=true'), key=lambda job: job['name'].lower())

if localonly is True:
    jobs = [j for j in jobs if 'isActive' not in j or j['isActive'] is not False]

for job in jobs:
    tenantTail = ''
    if 'tenantId' in job:
        tenantTail = '&tenantId=%s' % job['tenantId']
    if excludeenvironment is None or len(excludeenvironment) == 0 or (job['environment'].lower() not in excludeenvironment and job['environment'][1:].lower() not in excludeenvironment):

        startfrom = 0
        ro = api('get', '/searchvms?allUnderHierarchy=true&jobIds=%s&size=%s&from=%s%s%s' % (job['id'], pagesize, startfrom, etail, tenantTail))
        if len(ro) > 0:
            while True:
                if 'vms' in ro:
                    ro['vms'].sort(key=lambda obj: obj['vmDocument']['jobName'])
                    for vm in ro['vms']:
                        doc = vm['vmDocument']
                        jobId = doc['objectId']['jobId']
                        jobName = doc['jobName']
                        objName = doc['objectName']
                        objType = environments[doc['registeredSource']['type']]
                        objSource = doc['registeredSource']['displayName']
                        objAlias = ''
                        sqlAagName = ''
                        if 'sqlEntity' in doc['objectId']['entity'] and 'dbAagName' in doc['objectId']['entity']['sqlEntity']:
                            sqlAagName = doc['objectId']['entity']['sqlEntity']['dbAagName']
                        if 'objectAliases' in doc:
                            objAlias = doc['objectAliases'][0]
                            if objAlias == objName + '.vmx':
                                objAlias = ''
                            if objType == 'VMware':
                                objAlias = ''
                        if objType == 'View':
                            objSource = ''

                        if objAlias != '':
                            sourceName = objAlias
                        else:
                            sourceName = objSource

                        versions = sorted(doc['versions'], key=lambda s: s['instanceId']['jobStartTimeUsecs'])
                        if days is not None:
                            versions = [v for v in versions if v['instanceId']['jobStartTimeUsecs'] >= daysBackUsecs]
                        versionCount = len(versions)
                        if versionCount > 0:
                            oldestSnapshotDate = usecsToDate(versions[0]['instanceId']['jobStartTimeUsecs'])
                            newsetSnapshotDate = usecsToDate(versions[-1]['instanceId']['jobStartTimeUsecs'])
                        else:
                            oldestSnapshotDate = ''
                            newsetSnapshotDate = ''
                        print("%s (%s) %s: %s" % (jobName, objType, objName, versionCount))
                        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], jobName, objType, sourceName, objName, sqlAagName, versionCount, oldestSnapshotDate, newsetSnapshotDate))
                if ro['count'] > (pagesize + startfrom):
                    startfrom += pagesize
                    ro = api('get', '/searchvms?allUnderHierarchy=truejobIds=%s&size=%s&from=%s%s%s' % (job['id'], pagesize, startfrom, etail, tenantTail))
                else:
                    break
f.close()

if mailserver is not None and sendto is not None and sendfrom is not None:
    msg = MIMEMultipart()
    msg['From'] = sendfrom
    msg['To'] = ', '.join(sendto)
    msg['Subject'] = "active snapshots report for %s" % cluster['name']
    body = "active snapshots report for %s\n\n" % cluster['name']
    msg.attach(MIMEText(body, 'plain'))
    filename = 'activeSnapshots-%s.csv' % cluster['name']
    attachment = open(outfileName, "rb")
    part = MIMEBase('application', 'octet-stream')
    part.set_payload((attachment).read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', "attachment; filename= %s" % filename)
    msg.attach(part)
    smtp = smtplib.SMTP(mailserver, mailport)
    smtp.sendmail(sendfrom, sendto, msg.as_string())
    print('\nSending email report to %s\n' % ', '.join(sendto))
