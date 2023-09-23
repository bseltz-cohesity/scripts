#!/usr/bin/env python
"""list gflags with python"""

# import pyhesity wrapper module
from pyhesity import *
import requests
import urllib3
import codecs
import requests.packages.urllib3
import sys
if sys.version_info.major >= 3 and sys.version_info.minor >= 5:
    from urllib.parse import quote_plus
else:
    from urllib import quote_plus

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-a', '--accesscluster', type=str, default=None)
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-s', '--servicename', type=str, default=None)
parser.add_argument('-n', '--flagname', type=str, default=None)
parser.add_argument('-f', '--flagvalue', type=str, default=None)
parser.add_argument('-r', '--reason', type=str, default=None)
parser.add_argument('-e', '--effectivenow', action='store_true')
parser.add_argument('-c', '--clear', action='store_true')
parser.add_argument('-i', '--importfile', type=str, default=None)
parser.add_argument('-x', '--restartservices', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
accesscluster = args.accesscluster
useApiKey = args.useApiKey
password = args.password
servicename = args.servicename
flagname = args.flagname
flagvalue = args.flagvalue
reason = args.reason
effectivenow = args.effectivenow
importfile = args.importfile
clear = args.clear
restartservices = args.restartservices

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

### constants
port = {
    "nexus": "23456",
    "iris": "443",
    "stats": "25566",
    "eagle_agent": "23460",
    "vault_proxy": "11115",
    "athena": "25681",
    "iris_proxy": "24567",
    "atom": "20005",
    "smb2_proxy": "20007",
    "bifrost_broker": "29992",
    "bifrost": "29994",
    "alerts": "21111",
    "bridge": "11111",
    "keychain": "22000",
    "smb_proxy": "20003",
    "bridge_proxy": "11116",
    "groot": "26999",
    "apollo": "24680",
    "tricorder": "23458",
    "magneto": "20000",
    "rtclient": "12321",
    "nexus_proxy": "23457",
    "gandalf": "22222",
    "patch": "30000",
    "librarian": "26000",
    "yoda": "25999",
    "storage_proxy": "20001",
    "statscollector": "25680",
    "newscribe": "12222",
    "icebox": "29999",
    "janus": "64001",
    "pushclient": "64002",
    "nfs_proxy": "20010",
    "icebox": "29999",
    "throttler": "20008",
    "elrond": "26002",
    "heimdall": "26200",
    "node_exporter": "9100",
    "compass": "25555",
    "etl_server": "23462"
}

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# if connected to helios, select to access cluster
if vip.lower() == 'helios.cohesity.com':
    if accesscluster is not None:
        heliosCluster(accesscluster)
    else:
        print('-accessCluster is required')
        exit()

cluster = api('get', 'cluster')
if effectivenow is True:
    nodes = api('get', 'nodes')


def setGflag(servicename, flagname, flagvalue, reason):
    print('\nsetting %s: %s = %s' % (servicename, flagname, flagvalue))
    gflag = {
        'clusterId': cluster['id'],
        'serviceName': servicename,
        'gflags': [
            {
                'name': flagname,
                'value': flagvalue,
                'reason': reason
            }
        ]
    }

    if clear is True:
        gflag['clear'] = True

    response = api('post', '/nexus/cluster/update_gflags', gflag)

    if effectivenow is True:
        print('    making effective now on all nodes')
        context = getContext()
        cookies = context['SESSION'].cookies.get_dict()
        nodes = api('get', 'nodes')
        for node in nodes:
            print('        %s' % node['ip'])
            if clear is True:
                if servicename == 'iris':
                    currentflags = context['SESSION'].get('https://%s:%s/flagz' % (node['ip'], port[servicename]), verify=False, headers=context['HEADER'], cookies=cookies)
                else:
                    currentflags = context['SESSION'].get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + port[servicename] + quote_plus('/flagz'), verify=False, headers=context['HEADER'])
                for existingflag in currentflags.content.split('\n'):
                    parts = str(existingflag).split('=')
                    existingflagname = parts[0][2:]
                    if existingflagname == flagname:
                        if len(parts) > 2:
                            flagvalue = parts[2][0:-1]
            if servicename == 'iris':
                response = context['SESSION'].get('https://%s:%s/flagz?%s=%s' % (node['ip'], port[servicename], flagname, flagvalue), verify=False, headers=context['HEADER'], cookies=cookies)
            else:
                response = context['SESSION'].get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + port[servicename] + quote_plus('/flagz?') + '%s=%s' % (flagname, flagvalue), verify=False, headers=context['HEADER'])


servicestorestart = []
servicescantrestart = []

# set a flag
if flagvalue is not None:
    if servicename is None or flagname is None or reason is None:
        print('-servicename, -flagname, -flagvalue and -reason are all required to set a gflag')
        exit()
    else:
        setGflag(servicename=servicename, flagname=flagname, flagvalue=flagvalue, reason=reason)
        servicestorestart.append(servicename)

# import gflags fom export file
flagdata = []
if importfile is not None:
    f = codecs.open(importfile, 'r', 'utf-8')
    flagdata += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
    for f in flagdata[1:]:
        (servicename, flagname, flagvalue, reason) = f.split(',', 3)
        flagvalue = flagvalue.replace(';;', ',')
        setGflag(servicename=servicename, flagname=flagname, flagvalue=flagvalue, reason=reason)
        if servicename.lower() != 'nexus':
            servicestorestart.append(servicename)
        else:
            servicescantrestart.append(servicename)

# write gflags to export file
print('\nCurrent GFlags:')
exportfile = 'gflags-%s.csv' % cluster['name']
f = codecs.open(exportfile, 'w', 'utf-8')
f.write('Service Name,Flag Name,Flag Value,Reason\n')

# get currrent flags
flags = api('get', '/nexus/cluster/list_gflags')

for service in flags['servicesGflags']:
    servicename = service['serviceName']
    print('\n%s:' % servicename)
    gflags = service['gflags']
    for gflag in gflags:
        flagname = gflag['name']
        flagvalue = gflag['value']
        reason = gflag['reason']
        print('    %s: %s (%s)' % (flagname, flagvalue, reason))
        flagvalue = flagvalue.replace(',', ';;')
        f.write('%s,%s,%s,%s\n' % (servicename, flagname, flagvalue, reason))

f.close()

if restartservices is True:
    print('\nRestarting required services...\n')
    restartParams = {
        "clusterId": cluster['id'],
        "services": list(set(servicestorestart))
    }
    response = api('post', '/nexus/cluster/restart', restartParams)

if restartservices is True and len(servicescantrestart) > 0:
    print('\nCant restart services: %s\n' % ', '.join(servicescantrestart))

print('\nGflags saved to %s\n' % exportfile)
