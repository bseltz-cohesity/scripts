#!/usr/bin/env python
"""List Recovery Points for python"""

### usage: ./clusterInfo.py -v mycluster \
#                           -u admin \
#                           -d local \
#                           -s 192.168.1.95 \
#                           -f backupreport@mydomain.net

### import pyhesity wrapper module
from pyhesity import *
import datetime
import requests
import smtplib
from email.mime.multipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email import Encoders

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--mailserver', type=str)
parser.add_argument('-p', '--mailport', type=int, default=25)
parser.add_argument('-t', '--sendto', action='append', type=str)
parser.add_argument('-f', '--sendfrom', type=str)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
mailserver = args.mailserver
mailport = args.mailport
sendto = args.sendto
sendfrom = args.sendfrom

### authenticate
apiauth(vip, username, domain)

cluster = api('get', 'cluster')

dateString = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
outfileName = 'clusterInfo-%s-%s.txt' % (cluster['name'], dateString)
f = open(outfileName, "w")

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
output('    Cluster Name: %s' % status['clusterConfig']['proto']['clusterPartitionVec'][0]['hostName'])
output('      Cluster ID: %s' % status['clusterId'])
output('  Healing Status: %s' % status['healingStatus'])
output('    Service Sync: %s' % status['isServiceStateSynced'])
output('Stopped Services: %s' % status['bulletinState']['stoppedServices'])
output('------------------------------------\n')
for chassis in chassisList:
    # chassis info
    output('  Chassis Name: %s' % chassis['name'])
    output('    Chassis ID: %s' % chassis['id'])
    output('      Hardware: %s' % chassis.get('hardwareModel', 'VirtualEdition'))
    gotSerial = False
    for node in nodeList:
        if node['chassisId'] == chassis['id']:
            # node info
            nodeInfo = requests.get('http://' + node['ip'].split(':')[-1] + ':23456/nexus/v1/node/info')
            nodeJson = nodeInfo.json()
            if gotSerial is False:
                output('Chassis Serial: %s' % nodeJson['chassisSerial'])
                gotSerial = True
            output('\n           Node ID: %s' % node['id'])
            output('           Node IP: %s' % node['ip'].split(':')[-1])
            output('           IPMI IP: %s' % nodeJson.get('ipmiIp', 'n/a'))
            productModel = nodeJson['productModel']

            output('           Slot No: %s' % node.get('slotNumber', 0))
            output('         Serial No: %s' % node.get('serialNumber', 'VirtualEdition'))
            output('     Product Model: %s' % productModel)
            output('        SW Version: %s' % node['softwareVersion'])
            for stat in nodeStatus:
                if stat['nodeId'] == node['id']:
                    output('            Uptime: %s\n' % stat['uptime'])

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
