#!/usr/bin/env python

from pyhesity import *
from time import sleep
import getpass
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-e', '--emailmfacode', action='store_true')
parser.add_argument('-n', '--hostname', action='append', type=str)
parser.add_argument('-p', '--scriptdir', type=str, default='/opt/cohesity/db2/scripts')
parser.add_argument('-kp', '--kerberosprincipal', type=str, default='')
parser.add_argument('-kt', '--kerberoskeytab', type=str, default='')
parser.add_argument('-kc', '--kerberoscache', type=str, default='')
parser.add_argument('-cp', '--certificatepath', type=str, default='')
parser.add_argument('-dn', '--datasourcename', type=str, required=True)
parser.add_argument('-pu', '--protectionusername', type=str, default='')
parser.add_argument('-in', '--instancename', type=str, default='')
parser.add_argument('-pp', '--profilepath', type=str, required=True)
parser.add_argument('-ev', '--environmentvariables', type=str, default='')
parser.add_argument('-la', '--logarchive', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
hostnames = args.hostname
scriptdir = args.scriptdir
kerberosprincipal = args.kerberosprincipal
kerberoskeytab = args.kerberoskeytab
kerberoscache = args.kerberoscache
certificatepath = args.certificatepath
datasourcename = args.datasourcename
protectionusername = args.protectionusername
instancename = args.instancename
profilepath = args.profilepath
environmentvariables = args.environmentvariables
logarchive = args.logarchive

archiveToCohesity = "false"
if logarchive is True:
    archiveToCohesity = "true"

if hostnames is None or len(hostnames) == 0:
    print('hostname required')
    exit(1)

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode, tenantId=tenant)

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


def waitForRefresh(id):
    authStatus = ""
    while authStatus != 'kFinished':
        sleep(3)
        rootNode = (api('get', 'protectionSources/registrationInfo?ids=%s' % id))['rootNodes'][0]
        authStatus = rootNode['registrationInfo']['authenticationStatus']
        if authStatus != 'kFinished':
            print(authStatus)
    return rootNode['rootNode']['id']


regparams = {
    "environment": "kUDA",
    "udaParams": {
        "sourceType": "kDB2",
        "osType": "kLinux",
        "hosts": hostnames,
        "credentials": None,
        "scriptDir": scriptdir,
        "mountView": False,
        "viewParams": None,
        "sourceRegistrationArgs": None,
        "sourceRegistrationArguments": [
            {
                "key": "kerberos_principal",
                "value": kerberosprincipal
            },
            {
                "key": "kerberos_keytab",
                "value": kerberoskeytab
            },
            {
                "key": "kerberos_cache",
                "value": kerberoscache
            },
            {
                "key": "certificate_config_path",
                "value": certificatepath
            },
            {
                "key": "source_name",
                "value": datasourcename
            },
            {
                "key": "username",
                "value": protectionusername
            },
            {
                "key": "instance_name",
                "value": instancename
            },
            {
                "key": "profile_path",
                "value": profilepath
            },
            {
                "key": "environment_variables",
                "value": environmentvariables
            },
            {
                "key": "archive_to_cohesity",
                "value": archiveToCohesity
            }
        ]
    }
}
display(regparams)

print("Registering DB2 UDA protection source '%s'..." % hostnames[0])
result = api('post', 'data-protect/sources/registrations', regparams, v=2)
if 'id' in result:
    id = waitForRefresh(result['id'])
