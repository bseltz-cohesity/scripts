#!/usr/bin/env python
"""Show FlashBlade Protection Status"""

# usage:
# ./flashBladeProtectionStatus.py -v mycluster \
#                                 -u myuser \
#                                 -d mydomain.net \
#                                 -f flashblad01

# import pyhesity wrapper module
from pyhesity import *

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)       # Cohesity cluster name or IP
parser.add_argument('-u', '--username', type=str, required=True)  # Cohesity Username
parser.add_argument('-d', '--domain', type=str, default='local')  # Cohesity User Domain
parser.add_argument('-f', '--flashbladesource', type=str, required=True)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
flashbladesource = args.flashbladesource

# authenticate
apiauth(vip, username, domain)

# get flashblade source
sources = api('get', 'protectionSources?environments=kFlashBlade')
flashblade = [s for s in sources if s['protectionSource']['name'].lower() == flashbladesource.lower()]
if len(flashblade) < 1:
    print('FlashBlade %s not registered in Cohesity' % flashbladesource)
    exit(1)
else:
    flashblade = flashblade[0]
parentId = flashblade['protectionSource']['id']

# get protected volume names
protectedvolumes = api('get', 'protectionSources/protectedObjects?id=%s&environment=kFlashBlade' % parentId)
protectedVolumeNames = [v['protectionSource']['name'] for v in protectedvolumes]

outfile = '%s-unprotected.txt' % flashbladesource
f = open(outfile, 'w')

for volume in flashblade['nodes']:
    volumename = volume['protectionSource']['name']
    if volumename in protectedVolumeNames:
        print('  PROTECTED: %s' % volumename)
    else:
        print('UNPROTECTED: %s' % volumename)
        f.write('%s\n' % volumename)

f.close()
print('\nunprotected volumes saved to %s' % outfile)
