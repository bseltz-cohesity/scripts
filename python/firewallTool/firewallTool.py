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
parser.add_argument('-p', '--profile', type=str, choices=['Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS', ''], default='')

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

if profile == '':
    print('no profile specified')
    exit(1)

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
        exit(1)

if apiconnected() is False:
    print('authentication failed')
    exit(1)


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

if action != 'list' and len(entries) == 0:
    print('No entries specified')
    exit(1)

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

if action != 'list':
    result = api('put', '/nexus/v1/firewall/update', rules)
    if 'error' in result:
        exit(1)
print('\n%s allow list:' % profile)
for attachment in rules['entry']['attachments']:
    if attachment['profile'] == profile:
        if attachment['subnets'] is None or len(attachment['subnets']) == 0:
            print('    All IP Addresses(*)')
        else:
            for cidr in attachment['subnets']:
                print('    %s' % cidr)
print('')
