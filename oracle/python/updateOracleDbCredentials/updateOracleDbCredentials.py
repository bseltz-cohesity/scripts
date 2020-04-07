#!/usr/bin/env python
"""Update Oracle DB Credentials"""

### import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, required=True)
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-s', '--oracleserver', type=str, required=True)
parser.add_argument('-o', '--oracleuser', type=str, required=True)
parser.add_argument('-p', '--oraclepwd', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
oracleserver = args.oracleserver
oracleuser = args.oracleuser
oraclepwd = args.oraclepwd

### authenticate
apiauth(vip, username, domain)

sources = api('get', '/backupsources?envTypes=19')

if sources is not None:
    source = [source for source in sources['entityHierarchy']['children'][0]['children'] if source['entity']['displayName'].lower() == oracleserver.lower()]
    if len(source) == 0:
        print('Oracle server %s not found!' % oracleserver)
        exit(1)

sourceParams = {
    'appEnvVec': [
        19
    ],
    'usesPersistentAgent': True,
    'ownerEntity': source[0]['entity'],
    'appCredentialsVec': [
        {
            'envType': 19,
            'credentials': {
                'username': oracleuser,
                'password': oraclepwd
            }
        }
    ]
}
result = api('put', '/applicationSourceRegistration', sourceParams)
if result is not None:
    print("DB credentials updated")
else:
    print("Something went wrong")
