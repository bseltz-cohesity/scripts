#!/usr/bin/env python

from pyhesity import *
import sys
import getpass
import codecs
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-sn', '--sourcename', type=str, required=True)
parser.add_argument('-n', '--rdsname', action='append', type=str)
parser.add_argument('-l', '--rdslist', type=str)
parser.add_argument('-t', '--rdstype', type=str, choices=['kAuroraCluster', 'kRDSInstance'])
parser.add_argument('-d', '--dbengine', type=str)
parser.add_argument('-x', '--update', action='store_true')
parser.add_argument('-ru', '--rdsuser', type=str)
parser.add_argument('-rp', '--rdspassword', type=str)
parser.add_argument('-rn', '--realmname', type=str)
parser.add_argument('-rd', '--realmdnsaddress', type=str)
parser.add_argument('-a', '--authtype', type=str, choices=['credentials', 'iam', 'kerberos'], default='credentials')

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
sourcename = args.sourcename
rdsnames = args.rdsname
rdslist = args.rdslist
rdstype = args.rdstype
dbengine = args.dbengine
update = args.update
rdsuser = args.rdsuser
rdspassword = args.rdspassword
realmname = args.realmname
realmdnsaddress = args.realmdnsaddress
authtype = args.authtype

# identify python version


def prompt(thisprompt):
    if sys.version_info[0] < 3:
        selected = raw_input('%s: ' % thisprompt)
    else:
        selected = input('%s: ' % thisprompt)
    return selected

# gather server list
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
        exit()
    return items

rdsnames = gatherList(rdsnames, rdslist, name='RDS instances', required=False)

# authentication =========================================================
apiauth(username=username, password=password, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

# gather required credentials
if update is True:
    if rdsuser is None or (authtype != 'iam' and rdspassword is None) or (authtype == 'kerberos' and (realmname is None or realmdnsaddress is None)):
        print('\nPrompting for required RDS credentials:')
        if rdsuser is None:
            rdsuser = prompt('        RDS Username')
        if authtype != 'iam':
            if rdspassword is None:
                while(True):
                    rdspassword = getpass.getpass("        RDS Password: ")
                    confirmpassword = getpass.getpass("Confirm RDS Password: ")
                    if rdspassword == confirmpassword:
                        break
                    else:
                        print('\nPasswords do not match')
        if authtype == 'kerberos':
            if realmname is None:
                realmname = prompt('          Realm Name')
            if realmdnsaddress is None:
                realmdnsaddress = prompt('   Realm DNS Address')
        print('')

# gather helios tenant info
sessionUser = api('get', 'sessionUser')
tenantId = sessionUser['profiles'][0]['tenantId']
regions = api('get', 'dms/tenants/regions?tenantId=%s' % tenantId, mcmv2=True)
regionList = ','.join([r['regionId'] for r in regions['tenantRegionInfoList']])

# find registered source
sources = api('get', 'data-protect/sources?regionIds=%s&environments=kAWS' % regionList, mcmv2=True)
if sources is None or 'sources' not in sources or sources['sources'] is None or len(sources['sources']) == 0:
    print('No AWS sources found')
    exit(1)
source = [s for s in sources['sources'] if s['name'].lower() == sourcename.lower()]
if source is None or len(source) == 0:
    print('AWS source %s not found' % sourcename)
    exit(1)

sourceId = source[0]['sourceInfoList'][0]['sourceId']
regionId = source[0]['sourceInfoList'][0]['regionId']
thisSource = api('get', 'protectionSources?useCachedData=false&includeVMFolders=true&includeSystemVApps=true&includeExternalMetadata=true&includeEntityPermissionInfo=true&id=%s&excludeTypes=kResourcePool&excludeAwsTypes=kEC2Instance,kTag,kS3Bucket,kS3Tag&environment=kAWS&allUnderHierarchy=false' % sourceId, region=regionId)

# find all rds instances
rdsNodes = []
regionNodes = [n for n in thisSource[0]['nodes'] if n['protectionSource']['awsProtectionSource']['type'] == 'kRegion']
for regionNode in regionNodes:
    if 'nodes' in regionNode:
        azNodes = [n for n in regionNode['nodes'] if n['protectionSource']['awsProtectionSource']['type'] == 'kAvailabilityZone']
        for azNode in azNodes:
            if 'nodes' in azNode:
                theseRdsNodes = [n for n in azNode['nodes'] if n['protectionSource']['awsProtectionSource']['type'] in ['kRDSInstance', 'kAuroraCluster'] and 'postgres' in n['protectionSource']['awsProtectionSource']['dbEngineId'].lower()]
                rdsNodes = rdsNodes + theseRdsNodes

# filter on instance type
if rdstype is not None:
    rdsNodes = [n for n in rdsNodes if n['protectionSource']['awsProtectionSource']['type'] == rdstype]

# filter on DB Engine
if dbengine is not None:
    rdsNodes = [n for n in rdsNodes if n['protectionSource']['awsProtectionSource']['dbEngineId'].lower() == dbengine.lower()]

# filter on instance name
if len(rdsnames) > 0:
    rdsNodes = [n for n in rdsNodes if n['protectionSource']['name'].lower() in [r.lower() for r in rdsnames]]
    notFound = [n for n in rdsnames if n.lower() not in [r['protectionSource']['name'].lower() for r in rdsNodes]]
    # report not found instances
    if len(notFound) > 0:
        for nf in notFound:
            print('%s not found' % nf)

if update is True:
    for n in sorted(rdsNodes, key=lambda node: node['protectionSource']['name'].lower()):
        name = n['protectionSource']['name']
        objectId = n['protectionSource']['id']
        dbEngine = n['protectionSource']['awsProtectionSource']['dbEngineId']
        type = n['protectionSource']['awsProtectionSource']['type']

        metaParams = {
            "sourceId": sourceId,
            "entityList": [
                {
                    "entityId": objectId,
                    "awsParams": {}
                }
            ]
        }
    
        if type == 'kAuroraCluster':
            metaParams['entityList'][0]['awsParams']['auroraParams'] = {}
            params = metaParams['entityList'][0]['awsParams']['auroraParams']
        else:
            metaParams['entityList'][0]['awsParams']['rdsParams'] = {}
            params = metaParams['entityList'][0]['awsParams']['rdsParams']

        params['dbEngineId'] = dbEngine
        params['metadataList'] = [
            {
                "metadataType": 'Credentials',
                "standardCredentials": {
                    "username": rdsuser,
                }
            }
        ]

        if authtype == 'credentials':
            params['metadataList'][0]['standardCredentials']['authType'] = 'kStandardCredentials'
            params['metadataList'][0]['standardCredentials']['password'] = rdspassword
        elif authtype == 'iam':
            params['metadataList'][0]['standardCredentials']['authType'] = 'kUseIAMRole'
            params['metadataList'][0]['standardCredentials']['password'] = None
        elif authtype == 'kerberos':
            params['metadataList'][0]['standardCredentials']['authType'] = 'kKerberos'
            params['metadataList'][0]['standardCredentials']['password'] = rdspassword
            params['metadataList'][0]['standardCredentials']['realmName'] = realmname
            params['metadataList'][0]['standardCredentials']['directoryDNSAddress'] = realmdnsaddress

        print('Updating %s' % name)
        # display(metaParams)
        result = api('put', 'data-protect/objects/metadata', metaParams, v=2, region=regionId)
else:
    print('')
    csvfileName = 'rds-instances.csv'
    csv = codecs.open(csvfileName, 'w', 'utf-8')
    csv.write('"Name","Type","DB Engine"\n')
    print('%16s %24s   %s' % ('RDS Type', 'DB Engine', 'Name'))
    print('%16s %24s   %s' % ('==============', '======================', '===================='))
    
    for n in sorted(rdsNodes, key=lambda node: node['protectionSource']['name'].lower()):
        print('%16s %24s   %s' % (n['protectionSource']['awsProtectionSource']['type'], n['protectionSource']['awsProtectionSource']['dbEngineId'], n['protectionSource']['name']))
        csv.write('"%s","%s","%s"\n' % (n['protectionSource']['name'], n['protectionSource']['awsProtectionSource']['type'], n['protectionSource']['awsProtectionSource']['dbEngineId']))
    csv.close()
    print('\nRDS list saved to %s\n' % csvfileName)
