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

if api_version < '2023.09.23':
    print('This script requires pyhesity.py version 2023.09.23 or later')
    exit()

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-a', '--accesscluster', type=str, default=None)
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-p', '--password', type=str, default=None)
parser.add_argument('-s', '--servicename', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
accesscluster = args.accesscluster
useApiKey = args.useApiKey
password = args.password
servicename = args.servicename

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

exportfile = 'gflaglist-%s-%s.txt' % (servicename, cluster['name'])
f = codecs.open(exportfile, 'w', 'utf-8')

nodes = api('get', 'nodes')
context = getContext()
# cookies = context['SESSION'].cookies.get_dict()
cookies = context['COOKIES']
for node in nodes:
    try:
        if servicename in port:
            if servicename == 'iris':
                currentflags = context['SESSION'].get('https://%s:%s/flagz' % (vip, port[servicename]), verify=False, headers=context['HEADER'], cookies=cookies)
            else:
                currentflags = context['SESSION'].get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + port[servicename] + quote_plus('/flagz'), verify=False, headers=context['HEADER'])
            existingflags = str(currentflags.content).split('\\n')
            for existingflag in existingflags:
                parts = str(existingflag).split('=')
                if parts[0][0:2] == '--':
                    flagname = parts[0][2:]
                    if len(parts) < 2:
                        flagvalue = None
                    else:
                        flagvalue = parts[1].split(' [default')[0]
                    print('%s: %s' % (flagname, flagvalue))
                    f.write('%s: %s\n' % (flagname, flagvalue))
            break
    except Exception:
        pass

f.close()

print('\nGflags saved to %s\n' % exportfile)
