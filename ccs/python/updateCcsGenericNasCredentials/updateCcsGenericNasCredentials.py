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
parser.add_argument('-r', '--region', type=str)
parser.add_argument('-sn', '--sourcename', action='append', type=str)
parser.add_argument('-sl', '--sourcelist', type=str)
parser.add_argument('-m', '--mode', type=str, choices=['kNfs3', 'kNfs4_1', 'kCifs1'])
parser.add_argument('-x', '--update', action='store_true')
parser.add_argument('-su', '--smbuser', type=str)
parser.add_argument('-sp', '--smbpassword', type=str)

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
region = args.region
sourcenames = args.sourcename
sourcelist = args.sourcelist
mode = args.mode
update = args.update
smbuser = args.smbuser
smbpassword = args.smbpassword

# check pyhesity version
if api_version < '2025.01.27':
    print('\nThis script requires pyhesity.py version 2025.01.27 or later. Get the latest version at:\n\nhttps://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity\n')
    exit(1)


def prompt(thisprompt):
    if sys.version_info[0] < 3:
        selected = raw_input('%s: ' % thisprompt)
    else:
        selected = input('%s: ' % thisprompt)
    return selected


# gather list from command line params and file
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


sourcenames = gatherList(sourcenames, sourcelist, name='Generic NAS sources', required=False)

# authentication =========================================================
apiauth(username=username, password=password, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

# gather required credentials
if update is True:
    if smbuser is None or smbpassword is None:
        print('\nPrompting for required SMB credentials:')
        if smbuser is None:
            smbuser = prompt('        SMB Username')
        if smbpassword is None:
            while(True):
                smbpassword = getpass.getpass("        SMB Password: ")
                confirmpassword = getpass.getpass("Confirm SMB Password: ")
                if smbpassword == confirmpassword:
                    break
                else:
                    print('\nPasswords do not match')
        print('')

# gather helios tenant info
print('Gathering tenant info...')
sessionUser = api('get', 'sessionUser')
tenantId = sessionUser['profiles'][0]['tenantId']
regions = api('get', 'dms/tenants/regions?tenantId=%s' % tenantId, mcmv2=True)
regionIds = [r['regionId'] for r in regions['tenantRegionInfoList']]

if region is not None:
    regionIds = [r for r in regionIds if r.lower() == region.lower()]
    if len(regionIds) == 0:
        print('region %s not found' % region)
        exit(1)
regionList = ','.join(regionIds)

# find registered generic NAS sources
print('Gathering registered NAS sources...')
sources = api('get', 'data-protect/sources?regionIds=%s&environments=kGenericNas' % regionList, mcmv2=True)
if sources is None or 'sources' not in sources or sources['sources'] is None:
    nasSources = []
else:
    nasSources = [s for s in sources['sources'] if s.get('environment', 'kGenericNas') == 'kGenericNas']

# filter on source name
if len(sourcenames) > 0:
    lowernames = [n.lower() for n in sourcenames]
    nasSources = [s for s in nasSources if s['name'].lower() in lowernames]
    foundnames = [s['name'].lower() for s in nasSources]
    notFound = [n for n in sourcenames if n.lower() not in foundnames]
    # report not found sources
    for nf in sorted(notFound):
        print('%s not found' % nf)

# get registration details for each source (mount mode)
nasInfo = []
for nasSource in sorted(nasSources, key=lambda s: s['name'].lower()):
    for sourceInfo in nasSource['sourceInfoList']:
        registrationId = sourceInfo.get('registrationId', None)
        registration = None
        if registrationId is not None:
            registration = api('get', 'data-protect/sources/registrations/%s' % registrationId, mcmv2=True)
        nasParams = {}
        if registration is not None and 'genericNasParams' in registration and registration['genericNasParams'] is not None:
            nasParams = registration['genericNasParams']
        smbCreds = nasParams.get('smbMountCredentials', None) or {}
        nasInfo.append({
            'name': nasSource['name'],
            'registrationId': registrationId,
            'regionId': sourceInfo.get('regionId', None),
            'mountPoint': nasParams.get('mountPoint', None),
            'mode': nasParams.get('mode', None),
            'description': nasParams.get('description', None),
            'currentUser': smbCreds.get('username', None),
            'registration': registration
        })

# filter on mount mode
if mode is not None:
    nasInfo = [n for n in nasInfo if n['mode'] == mode]

# if no sources were specified, operate on all sources currently using smbuser
if len(sourcenames) == 0 and smbuser is not None:
    nasInfo = [n for n in nasInfo if n['currentUser'] is not None and n['currentUser'].lower() == smbuser.lower()]
    if len(nasInfo) == 0:
        print('No Generic NAS sources found using SMB user %s' % smbuser)

if update is True:
    for nas in nasInfo:
        if nas['mode'] != 'kCifs1':
            print('Skipping %s (mode %s does not use credentials)' % (nas['name'], nas['mode']))
            continue
        if nas['registrationId'] is None:
            print('Skipping %s (no registration id found)' % nas['name'])
            continue
        registrationParams = {
            "environment": "kGenericNas",
            "genericNasParams": {
                "mountPoint": nas['mountPoint'],
                "mode": nas['mode'],
                "skipValidation": False,
                "smbMountCredentials": {
                    "username": smbuser,
                    "password": smbpassword
                }
            }
        }
        if nas['description'] is not None and nas['description'] != '':
            registrationParams['genericNasParams']['description'] = nas['description']
        oldParams = nas['registration']['genericNasParams']
        if 'throttlingConfig' in oldParams and oldParams['throttlingConfig'] is not None:
            registrationParams['genericNasParams']['throttlingConfig'] = oldParams['throttlingConfig']
        if 'connectorGroupId' in nas['registration'] and nas['registration']['connectorGroupId'] is not None:
            registrationParams['connectorGroupId'] = nas['registration']['connectorGroupId']
        print('Updating %s' % nas['name'])
        # display(registrationParams)
        result = api('put', 'data-protect/sources/registrations/%s' % nas['registrationId'], registrationParams, mcmv2=True)
else:
    print('')
    csvfileName = 'genericnas-sources.csv'
    csv = codecs.open(csvfileName, 'w', 'utf-8')
    csv.write('"Mount Point","Region","Mode","SMB User"\n')
    # size columns to fit the data
    mpWidth = max([len(str(n['mountPoint'])) for n in nasInfo] + [len('Mount Point')])
    rgWidth = max([len(str(n['regionId'])) for n in nasInfo] + [len('Region')])
    mdWidth = max([len(str(n['mode'])) for n in nasInfo] + [len('Mode')])
    fmt = '%%-%ds  %%-%ds  %%-%ds  %%s' % (mpWidth, rgWidth, mdWidth)
    print(fmt % ('Mount Point', 'Region', 'Mode', 'SMB User'))
    print(fmt % ('=' * mpWidth, '=' * rgWidth, '=' * mdWidth, '=' * 8))
    for n in nasInfo:
        print(fmt % (n['mountPoint'], n['regionId'], n['mode'], n['currentUser']))
        csv.write('"%s","%s","%s","%s"\n' % (n['mountPoint'], n['regionId'], n['mode'], n['currentUser']))
    csv.close()
    print('\nGeneric NAS source list saved to %s\n' % csvfileName)
