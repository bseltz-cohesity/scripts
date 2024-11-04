#!/usr/bin/env python
"""agent certificate check 2024-08-09"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs
import os
import re

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
parser.add_argument('-w', '--excludewindows', action='store_true')
parser.add_argument('-x', '--expirywarningmonths', type=int, default=6)
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
excludewindows = args.excludewindows
expirywarningmonths = args.expirywarningmonths

expwarningusecs = dateToUsecs() + (expirywarningmonths * 2592000000000)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, tenantId=tenant)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

now = datetime.now()
dateString = now.strftime("%Y-%m-%d-%H-%M-%S")

if mcm or vip.lower() == 'helios.cohesity.com':
    impactfile = 'impactedAgents-helios-%s.txt' % dateString
    outfile = 'agentCertificateCheck-helios-%s.csv' % dateString
    if clusternames is None or len(clusternames) == 0:
        clusternames = [c['name'] for c in heliosClusters()]
else:
    cluster = api('get', 'cluster')
    clusternames = [cluster['name']]
    cluster = api('get', 'cluster')
    outfile = 'agentCertificateCheck-%s-%s.csv' % (cluster['name'], dateString)
    impactfile = 'impactedAgents-%s-%s.txt' % (cluster['name'], dateString)

i = codecs.open(impactfile, 'w')
f = codecs.open(outfile, 'w')
f.write('Cluster Name,Agent Name,Status,Cluster Version,MultiTenancy,Agent Version,Agent Port,OS Type,OS Name,SAN Match,Cert Expires,Error Message\n')

for clustername in clusternames:
    print('\nConnecting to %s...\n' % clustername)
    if mcm or vip.lower() == 'helios.cohesity.com':
        heliosCluster(clustername)

    cluster = api('get', 'cluster')
    clusterVersion = cluster['clusterSoftwareVersion']
    orgsenabled = cluster['multiTenancyEnabled']

    # agent gflags
    try:
        flags = api('get', '/nexus/cluster/list_gflags')
        gflaglist = []

        for service in flags['servicesGflags']:
            servicename = service['serviceName']
            if servicename == 'magneto':
                gflags = service['gflags']
                for gflag in gflags:
                    if 'agent_port_number' in gflag['name']:
                        gflaglist.append({
                            'name': gflag['name'],
                            'value': gflag['value']
                        })
    except Exception:
        pass

    nodes = api('get', 'protectionSources/registrationInfo?allUnderHierarchy=true')
    hosts = api('get', '/nexus/cluster/get_hosts_file')
    if nodes is not None and 'rootNodes' in nodes and nodes['rootNodes'] is not None:
        nodesCounted = 0
        for node in nodes['rootNodes']:
            port = 50051
            name = node['rootNode']['name']
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
            sanMatch = False
            errorMessage = 'None'
            paramkey = None
            try:
                if 'vmWareProtectionSource' in node['rootNode']:
                    paramkey = node['rootNode']['vmWareProtectionSource']
                    try:
                        hostType = paramkey['hostType'][1:]
                        osName = 'VMware VM'
                    except Exception:
                        pass
                if 'physicalProtectionSource' in node['rootNode']:
                    paramkey = node['rootNode']['physicalProtectionSource']
                    hostType = paramkey['hostType'][1:]
                    osName = node['rootNode']['physicalProtectionSource']['osName']
                if 'hypervProtectionSource' in node['rootNode']:
                    paramkey = node['rootNode']['hypervProtectionSource']
                    osName = 'HyperV'
                    hostType = 'Windows'
                    try:
                        thisSource = api('get', 'protectionSources?id=%s' % node['rootNode']['id'])
                        if thisSource is not None and len(thisSource) > 0:
                            if 'nodes' in thisSource[0] and thisSource[0]['nodes'] is not None and len(thisSource[0]['nodes']) > 0:
                                for thisNode in thisSource[0]['nodes']:
                                    if thisNode['protectionSource']['hypervProtectionSource']['type'] in ['kHostGroup', 'kHostCluster', 'kHypervHost']:
                                        if 'nodes' in thisNode:
                                            nodes['rootNodes'].append({
                                                'rootNode': thisNode['protectionSource'],
                                                'nodes': thisNode['nodes']
                                            })
                                        else:
                                            nodes['rootNodes'].append({
                                                'rootNode': thisNode['protectionSource'],
                                            })
                    except Exception:
                        pass
                if 'agents' in paramkey:
                    version = paramkey['agents'][0]['version']
                    if excludewindows is not True or hostType != 'Windows':
                        nodesCounted += 1
                        agentGflag = [f['value'] for f in gflaglist if f['name'] == 'magneto_agent_port_number']
                        if agentGflag is not None and len(agentGflag) > 0:
                            port = agentGflag[0]
                        agentGflag = [f['value'] for f in gflaglist if f['name'] == 'magneto_%s_agent_port_number' % hostType.lower()]
                        if agentGflag is not None and len(agentGflag) > 0:
                            port = agentGflag[0]
                        try:
                            if 'authenticationErrorMessage' in node['registrationInfo'] and node['registrationInfo']['authenticationErrorMessage'] is not None:
                                errorMessage = node['registrationInfo']['authenticationErrorMessage'].split(',')[0].split('\n')[0]
                            if 'refreshErrorMessage' in node['registrationInfo'] and node['registrationInfo']['refreshErrorMessage'] is not None and node['registrationInfo']['refreshErrorMessage'] != '':
                                errorMessage = node['registrationInfo']['refreshErrorMessage'].split(',')[0].split('\n')[0]
                        except Exception:
                            pass
                        try:
                            # certinfo = os.popen('openssl s_client -showcerts -connect %s:%s </dev/null 2>/dev/null | openssl x509 -noout -text -certopt no_sigdump,no_pubkey,no_signame,no_issuer,no_version,no_header,no_serial,no_aux,no_subject 2>/dev/null' % (testname, port))
                            certinfo = os.popen('timeout 5 openssl s_client -showcerts -connect %s:%s </dev/null 2>/dev/null | openssl x509 -noout -text -certopt no_sigdump,no_pubkey,no_signame,no_issuer,no_version,no_header,no_serial,no_aux,no_subject 2>/dev/null' % (testname, port))
                            cilines = certinfo.readlines()
                            for line in cilines:
                                thisline = line.strip()
                                if thisline.startswith('Not After'):
                                    expires = re.split('= |: ', thisline, 1)[1].replace('  ', ' ')
                                    datetime_object = datetime.strptime(expires, '%b %d %H:%M:%S %Y %Z')
                                    expiresUsecs = dateToUsecs(datetime_object)
                                    if expiresUsecs < expwarningusecs:
                                        expiringSoon = True
                                    expires = datetime.strftime(datetime_object, "%m/%d/%Y %H:%M:%S")
                                if thisline.startswith('DNS:'):
                                    sans = thisline.split(', ')
                                    for san in sans:
                                        thissan = san.split(':')[1]
                                        if thissan.lower() == name.lower():
                                            sanMatch = True

                        except Exception:
                            expires = 'unknown'
            except Exception:
                pass
            if excludewindows is not True or hostType != 'Windows':
                if expires == 'unknown':
                    status = 'unreachable'
                else:
                    if expiringSoon is True:
                        status = 'impacted'
                        i.write('%s\n' % name)
                    else:
                        status = 'not impacted'
                if paramkey is not None and 'agents' in paramkey:
                    print('%s:%s,%s,(%s) %s -> %s (%s)' % (name, port, version, hostType, osName, expires, status))
                    f.write('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (cluster['name'], name, status, clusterVersion, orgsenabled, version, port, hostType, osName, sanMatch, expires, errorMessage))
        if nodesCounted == 0:
            print('** No agents interrogated (all filtered by command line options) **')
            f.write('%s,No agents interrogated (all filtered by command line options),,%s\n' % (cluster['name'], clusterVersion))
    else:
        print('** No physical protection sources found on the cluster **')
        f.write('%s,No agents registered on the cluster,,%s\n' % (cluster['name'], clusterVersion))
f.close()

i.close()
print('\nOutput saved to %s' % outfile)
print('Impacted agent names saved to %s\n' % impactfile)
