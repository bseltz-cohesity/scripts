#!/usr/bin/env python
"""base V2 example"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import os

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, action='append')
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-w', '--includewindows', action='store_true')
parser.add_argument('-x', '--expirywarningdate', type=str, default='2023-06-01 00:00:00')
args = parser.parse_args()

vip = args.vip
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
includewindows = args.includewindows
expirywarningdate = args.expirywarningdate

expwarningusecs = dateToUsecs(expirywarningdate)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), emailMfaCode=emailmfacode, mfaCode=mfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

now = datetime.now()
dateString = now.strftime("%Y-%m-%d-%H-%M-%S")

if mcm or vip.lower() == 'helios.cohesity.com':
    outfile = 'agentCertificateCheck-helios-%s.csv' % dateString
    if clusternames is None or len(clusternames) == 0:
        clusternames = [c['name'] for c in heliosClusters()]
else:
    cluster = api('get', 'cluster')
    clusternames = [cluster['name']]
    cluster = api('get', 'cluster')
    outfile = 'agentCertificateCheck-%s-%s.csv' % (cluster['name'], dateString)

f = codecs.open(outfile, 'w')
f.write('Cluster Name,Agent Name,Status,Cluster Version,MultiTenancy,Agent Version,OS Type,OS Name,Cert Expires\n')

for clustername in clusternames:
    print('Connecting to %s...' % clustername)
    if mcm or vip.lower() == 'helios.cohesity.com':
        heliosCluster(clustername)

    cluster = api('get', 'cluster')
    clusterVersion = cluster['clusterSoftwareVersion']
    orgsenabled = cluster['multiTenancyEnabled']

    nodes = api('get', 'protectionSources/registrationInfo?environments=kPhysical&allUnderHierarchy=true')
    hosts = api('get', '/nexus/cluster/get_hosts_file')

    for node in nodes['rootNodes']:
        name = node['rootNode']['physicalProtectionSource']['name']
        testname = name
        if hosts is not None and 'hosts' in hosts and hosts['hosts'] is not None and len(hosts['hosts']) > 0:
            ip = [h['ip'] for h in hosts['hosts'] if name.lower() in [d.lower() for d in h['domainName']]]
            if ip is not None and len(ip) > 0:
                testname = ip[0]
        hostType = 'unknown'
        osName = 'unknown'
        version = 'unknown'
        expiringSoon = False
        expires = 'unknown'
        # try:
        if 'agents' in node['rootNode']['physicalProtectionSource']:
            version = node['rootNode']['physicalProtectionSource']['agents'][0]['version']
            hostType = node['rootNode']['physicalProtectionSource']['hostType'][1:]
            osName = node['rootNode']['physicalProtectionSource']['osName']
            if includewindows is True or hostType != 'Windows':
                certinfo = os.popen('timeout 5 openssl s_client -showcerts -connect %s:50051 </dev/null 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null' % testname)
                cilines = certinfo.readlines()
                if len(cilines) >= 2:
                    expdate = cilines[2]
                    expires = expdate.strip().split('=')[1].replace('  ', ' ')
                    datetime_object = datetime.strptime(expires, '%b %d %H:%M:%S %Y %Z')
                    expiresUsecs = dateToUsecs(datetime_object)
                    if expiresUsecs < expwarningusecs:
                        expiringSoon = True
                    expires = datetime.strftime(datetime_object, "%m/%d/%Y %H:%M:%S")
                else:
                    expires = 'unknown'
        # except Exception:
        #     pass
        if includewindows is True or hostType != 'Windows':
            print('%s,%s,(%s) %s -> %s' % (name, version, hostType, osName, expires))
            if expires == 'unknown':
                status = 'unreachable'
            else:
                if expiringSoon is True:
                    status = 'impacted'
                else:
                    status = 'not impacted'
            f.write('%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (cluster['name'], name, status, clusterVersion, orgsenabled, version, hostType, osName, expires))
f.close()
print('\nOutput saved to %s\n' % outfile)
