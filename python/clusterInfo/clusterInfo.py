#!/usr/bin/env python
"""List Recovery Points for python"""

# version 2020-07-17

### usage: ./clusterInfo.py -v mycluster \
#                           -u admin \
#                           -d local \
#                           -s 192.168.1.95 \
#                           -f backupreport@mydomain.net

### import pyhesity wrapper module
from pyhesity import *
import datetime
# import requests
import smtplib
import codecs
from email.mime.multipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email import Encoders

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, required=True)
parser.add_argument('-l', '--listgflags', action='store_true')
parser.add_argument('-of', '--outfolder', type=str, default='.')
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
listgflags = args.listgflags
folder = args.outfolder
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom
useApiKey = args.useApiKey

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

cluster = api('get', 'cluster')

dateString = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
outfileName = '%s/%s-%s-clusterInfo.txt' % (folder, dateString, cluster['name'])
f = codecs.open(outfileName, 'w', 'utf-8')

status = api('get', '/nexus/cluster/status')
config = status['clusterConfig']['proto']
chassisList = config['chassisVec']
nodeList = config['nodeVec']
nodeStatus = status['nodeStatus']
diskList = config['diskVec']

title = 'clusterInfo: %s (%s)' % (cluster['name'], dateString)
emailtext = '%s\n\n' % title


def output(mystring):
    global emailtext
    print(mystring)
    f.write(mystring + '\n')
    emailtext += '%s\n' % mystring


# cluster info
output('\n------------------------------------')
output('     Cluster Name: %s' % status['clusterConfig']['proto']['clusterPartitionVec'][0]['hostName'])
output('       Cluster ID: %s' % status['clusterId'])
output('   Healing Status: %s' % status['healingStatus'])
output('     Service Sync: %s' % status['isServiceStateSynced'])
output(' Stopped Services: %s' % status['bulletinState']['stoppedServices'])
output('------------------------------------')
for chassis in chassisList:
    # chassis info
    output('\n   Chassis Name: %s' % chassis['name'])
    output('     Chassis ID: %s' % chassis['id'])
    output('       Hardware: %s' % chassis.get('hardwareModel', 'VirtualEdition'))
    gotSerial = False
    for node in nodeList:
        if node['chassisId'] == chassis['id']:
            # node info
            apiauth(node['ip'].split(':')[-1], username, domain, password=password, quiet=True, useApiKey=useApiKey)
            nodeInfo = api('get', '/nexus/node/hardware_info')
            if gotSerial is False:
                output(' Chassis Serial: %s' % nodeInfo['cohesityChassisSerial'])
                gotSerial = True
            output('\n            Node ID: %s' % node['id'])
            output('            Node IP: %s' % node['ip'].split(':')[-1])
            output('            IPMI IP: %s' % node.get('ipmiIp', 'n/a'))
            output('            Slot No: %s' % node.get('slotNumber', 0))
            output('          Serial No: %s' % nodeInfo.get('cohesityNodeSerial', 'VirtualEdition'))
            output('      Product Model: %s' % nodeInfo['productModel'])
            output('         SW Version: %s' % node['softwareVersion'])
            for stat in nodeStatus:
                if stat['nodeId'] == node['id']:
                    output('             Uptime: %s' % stat['uptime'])

if listgflags:
    output('\n--------\n Gflags\n--------')
    flags = api('get', '/nexus/cluster/list_gflags')
    for service in flags['servicesGflags']:
        servicename = service['serviceName']
        if len(service['gflags']) > 0:
            output('\n%s:\n' % servicename)
        gflags = service['gflags']
        for gflag in gflags:
            flagname = gflag['name']
            flagvalue = gflag['value']
            reason = gflag['reason']
            output('    %s: %s (%s)' % (flagname, flagvalue, reason))

output('')
f.close()

# email report
if mailserver is not None:
    print('Sending report to %s...' % ', '.join(sendto))
    msg = MIMEMultipart('alternative')
    msg['Subject'] = title
    msg['From'] = sendfrom
    msg['To'] = ','.join(sendto)
    part = MIMEBase('application', "octet-stream")
    part.set_payload(open(outfileName, "rb").read())
    Encoders.encode_base64(part)
    part.add_header('Content-Disposition', 'attachment; filename="%s"' % outfileName)
    msg.attach(part)
    smtpserver = smtplib.SMTP(mailserver, mailport)
    smtpserver.sendmail(sendfrom, sendto, msg.as_string())
    smtpserver.quit()
