#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-p', '--platform', type=str, choices=['Windows', 'Linux'], default='Windows')
parser.add_argument('-t', '--packageType', type=str, choices=['RPM', 'DEB', 'SuseRPM', 'Script'], default='RPM')

args = parser.parse_args()

username = args.username
password = args.password
noprompt = args.noprompt
platform = args.platform
packageType = args.packageType

# authentication =========================================================
apiauth(username=username, password=password, prompt=(not noprompt))

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)
# end authentication =====================================================

images = api('get', 'data-protect/agents/images?platform=%s' % platform, mcmv2=True)
if platform == 'Linux':
    extension = {'RPM': 'rpm', 'DEB': 'deb', 'SuseRPM': 'rpm', 'Script': 'sh'}
    package = [p for p in images['agents'][0]['PlatformSubTypes'] if p['packageType'] == packageType]
    downloadURL = package[0]['downloadURL']
    fileName = 'cohesity-agent.%s' % extension[packageType]
    print('Downloading %s agent (%s)...' % (platform, packageType))
else:
    downloadURL = images['agents'][0]['downloadURL']
    fileName = 'cohesity-agent.exe'
    print('Downloading %s agent...' % platform)

fileDownload(uri=downloadURL, fileName=fileName)
print('Agent downloaded: %s' % fileName)
