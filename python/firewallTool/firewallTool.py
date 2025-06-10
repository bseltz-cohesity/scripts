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
parser.add_argument('-ip', '--ip', action='append', type=str)
parser.add_argument('-l', '--iplist', type=str, default=None)
parser.add_argument('-a', '--addentry', action='store_true')
parser.add_argument('-r', '--removeentry', action='store_true')
parser.add_argument('-p', '--profile', type=str, choices=['Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS', 'Reporting database', ''], default='')

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
ip = args.ip
iplist = args.iplist
addentry = args.addentry
removeentry = args.removeentry
profile = args.profile

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, mfaCode=mfacode, emailMfaCode=emailmfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

# if connected to helios or mcm, select access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    heliosCluster(clustername)
    if LAST_API_ERROR() != 'OK':
        exit(1)
# end authentication =====================================================


# gather list function
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
        exit(1)
    return items


# get list of ip/cidr to process
entries = gatherList(ip, iplist, name='entries', required=False)

if addentry is True:
    action = 'add'
elif removeentry is True:
    action = 'remove'
else:
    action = 'list'

if profile == '' and action != 'list':
    print('no profile specified')
    exit(1)

profiles = ['Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS', 'Reporting database']

# get existing firewall rules
rules = api('get', '/nexus/v1/firewall/list')

for cidr in entries:
    if '/' not in cidr:
        cidr = '%s/32' % cidr
    for attachment in rules['entry']['attachments']:
        if attachment['profile'] == profile:
            if action != 'list':
                if attachment['subnets'] is not None:
                    attachment['subnets'] = [s for s in attachment['subnets'] if s != cidr]
                if action == 'add':
                    if attachment['subnets'] is None:
                        attachment['subnets'] = []
                    attachment['subnets'].append(cidr)
                    print('    %s: adding %s' % (profile, cidr))
                else:
                    print('    %s: removing %s' % (profile, cidr))
                rules['updateAttachment'] = True

if action != 'list' and len(entries) == 0:
    for attachment in rules['entry']['attachments']:
        if attachment['profile'] == profile:
            if action == 'add':
                attachment['subnets'] = None
                print('    %s: adding *' % profile)
            else:
                print('    %s: removing *' % profile)
            rules['updateAttachment'] = True

if action != 'list':
    result = api('put', '/nexus/v1/firewall/update', rules)
    if 'error' in result:
        exit(1)
else:
    for pname in sorted(profiles):
        if profile == '' or pname.lower() == profile.lower():
            print('\n%s:' % pname)
            for attachment in rules['entry']['attachments']:
                if attachment['profile'] == pname:
                    if attachment['subnets'] is None or len(attachment['subnets']) == 0:
                        print('    All IP Addresses(*) (%s)' % attachment['action'])
                    else:
                        for cidr in attachment['subnets']:
                            print('    %s (%s)' % (cidr, attachment['action']))
print('')
