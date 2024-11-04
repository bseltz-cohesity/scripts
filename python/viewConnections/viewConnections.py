#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--viewname', type=str, default=None)
parser.add_argument('-ip', '--clientip', type=str, default=None)
parser.add_argument('-p', '--protocol', type=str, choices=['NFS', 'nfs', 'SMB', 'smb', 'ALL', 'all'], default='all')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
mfacode = args.mfacode
emailmfacode = args.emailmfacode
viewname = args.viewname
protocol = args.protocol
clientip = args.clientip

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    if emailmfacode:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, emailMfaCode=True)
    else:
        apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, mfaCode=mfacode)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

if apiconnected() is False:
    print('authentication failed')
    exit(1)

cluster = api('get', 'cluster')
if cluster['clusterSoftwareVersion'] < '6.8':
    print('This script requires Cohesity version 6.8 or later')
    exit()

f = open('viewConnections.csv', 'w')
f.write('"Client IP","Domain or GID","Username or UID","View Name","View Path","Protocol","Connected (Sec)"\n')
connections = api('get', 'file-services/view-clients', v=2)
if 'clients' in connections and connections['clients'] is not None and len(connections['clients']) > 0:
    clients = connections['clients']
    if viewname is not None:
        clients = [c for c in clients if c['viewName'].lower() == viewname.lower()]
    if protocol.lower() != 'all':
        clients = [c for c in clients if c['protocol'].lower() == protocol.lower()]
    if clientip is not None:
        clients = [c for c in clients if c['ip'] == clientip]
    for client in sorted(clients, key=lambda c: c['ip']):
        if client['viewPath'] == '':
            client['viewPath'] = '/'
        print('\nClient IP: %s' % client['ip'])
        if client['protocol'] == 'SMB':
            client['viewPath'] = client['viewPath'].replace('/', '\\')
            cuserdomain = ''
            cusername = ''
            if 'username' in client:
                cusername = client['username']
            if 'userDomain' in client:
                cuserdomain = client['userDomain']
            print('Username: %s/%s' % (cuserdomain, cusername))
        if client['protocol'] == 'NFS':
            print('UID: %s, GID: %s' % (client['uid'], client['gid']))
        print('View Name: %s' % client['viewName'])
        print('View Path: %s' % client['viewPath'])
        print('Protocol: %s' % client['protocol'])
        connectedSeconds = int(round(client['connectedTimeUsecs'] / 1000000, 0))
        print('Connected: %s seconds' % connectedSeconds)
        if client['protocol'] == 'NFS':
            f.write('"%s","%s","%s","%s","%s","%s","%s"\n' % (client['ip'], client['gid'], client['uid'], client['viewName'], client['viewPath'], client['protocol'], connectedSeconds))
        if client['protocol'] == 'SMB':
            f.write('"%s","%s","%s","%s","%s","%s","%s"\n' % (client['ip'], client['userDomain'], client['username'], client['viewName'], client['viewPath'], client['protocol'], connectedSeconds))
print('\nOutput saved to viewConnections.csv\n')
f.close()
