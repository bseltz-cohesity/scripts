#!/usr/bin/env python
"""schedule healer using python"""

# import pyhesity wrapper module
from pyhesity import *
import requests
import urllib3
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
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode

# authentication =========================================================
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

requests.packages.urllib3.disable_warnings()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

port = {
    "apollo": "24680"
}

nodes = api('get', 'nodes')
context = getContext()
cookies = context['COOKIES']
for node in nodes:
    try:
        apollo = context['SESSION'].get('https://%s/siren/v1/remote?relPath=&remoteUrl=http' % vip + quote_plus('://') + node['ip'] + quote_plus(':') + port['apollo'] + quote_plus('/'), verify=False, headers=context['HEADER'], cookies=cookies)
        masterpath = str(apollo.content).split('Master V2 Location')[1].split('Is Running on App Node')[0].split('href="')[1].split('">')[0]
        schedule = context['SESSION'].get('https://%s%s' % (vip, masterpath) + quote_plus('/schedule?pipeline_name=Healer'), verify=False, headers=context['HEADER'], cookies=cookies)
        print(str(schedule.content).split('Schedule Pipeline')[-1].replace('&#39;', '').split('RequestID')[0].replace('?', '').replace(' Detail message', '\n Detail message'))
        break
    except Exception:
        print('skipped node')
        pass
