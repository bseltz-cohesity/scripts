#!/usr/bin/env python

from pyhesity import *
from time import sleep
import getpass
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-n', '--sourcename', action='append', type=str)
parser.add_argument('-t', '--sourcetype', type=str, choices=['CockroachDB', 'DB2', 'MySQL', 'Other', 'SapHana', 'SapMaxDB', 'SapOracle', 'SapSybase', 'SapSybaseIQ', 'SapASE'], default='Other')
parser.add_argument('-p', '--scriptpath', type=str, required=True)
parser.add_argument('-a', '--sourceargs', type=str, default=None)
parser.add_argument('-au', '--appusername', type=str, default='')
parser.add_argument('-ap', '--apppassword', type=str, default='')
parser.add_argument('-m', '--mountview', action='store_true')
parser.add_argument('-o', '--ostype', type=str, default='kLinux')
args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
sourcename = args.sourcename
sourcetype = args.sourcetype
scriptdir = args.scriptpath
sourceargs = args.sourceargs
appusername = args.appusername
apppassword = args.apppassword
mountview = args.mountview
ostype = args.ostype

# authenticate
if mcm:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=True)
else:
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

# if connected to helios or mcm, select to access cluster
if mcm or vip.lower() == 'helios.cohesity.com':
    if clustername is not None:
        heliosCluster(clustername)
    else:
        print('-clustername is required when connecting to Helios or MCM')
        exit()

# source types
sourceTypeName = {
    "SapMaxDB": "kSapMaxDB",
    "SapSybase": "kSapSybase",
    "DB2": "kDB2",
    "MySQL": "kMySQL",
    "SapASE": "kSapASE",
    "SapSybaseIQ": "kSapSybaseIQ",
    "CockroachDB": "kCockroachDB",
    "SapOracle": "kSapOracle",
    "Other": "kOther",
    "SapHana": "kSapHana"
}


def waitForRefresh(id):
    authStatus = ""
    while authStatus != 'kFinished':
        sleep(3)
        rootNode = (api('get', 'protectionSources/registrationInfo?ids=%s' % id))['rootNodes'][0]
        authStatus = rootNode['registrationInfo']['authenticationStatus']
        if authStatus != 'kFinished':
            print(authStatus)
    return rootNode['rootNode']['id']


if appusername != '' and apppassword == '':
    apppassword = getpass.getpass("Enter app password: ")

regparams = {
    "environment": "kUDA",
    "udaParams": {
        "sourceType": sourceTypeName[sourcetype],
        "hosts": sourcename,
        "credentials": {
            "username": appusername,
            "password": apppassword
        },
        "scriptDir": scriptdir,
        "mountView": False,
        "viewParams": None,
        "sourceRegistrationArgs": sourceargs,
        "osType": ostype
    }
}

if mountview:
    regparams['udaParams']['mountView'] = True

print("Registering UDA protection source '%s'..." % sourcename[0])
result = api('post', 'data-protect/sources/registrations', regparams, v=2)
if 'id' in result:
    id = waitForRefresh(result['id'])
