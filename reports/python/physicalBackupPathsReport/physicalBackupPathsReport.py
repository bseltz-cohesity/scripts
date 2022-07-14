#!/usr/bin/env python
"""backed up files list for python"""

# import pyhesity wrapper module
from pyhesity import *
import codecs
import argparse

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # username
parser.add_argument('-d', '--domain', type=str, default='local')      # domain - defaults to local
parser.add_argument('-i', '--useApiKey', action='store_true')         # use API key authentication
parser.add_argument('-pwd', '--password', type=str, default=None)     # optional password

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
useApiKey = args.useApiKey

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

jobs = api('get', 'data-protect/protection-groups?environments=kPhysical', v=2)

for job in [j for j in jobs['protectionGroups'] if 'isDeleted' not in j]:
    if job['physicalParams']['protectionType'] == 'kFile':
        print('%s' % job['name'])
        if 'globalExcludePaths' in job['physicalParams']['fileProtectionTypeParams'] and job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths'] is not None and len(job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']) > 0:
            gefilename = '%s-globalExcludePaths.txt' % job['name']
            gefile = codecs.open(gefilename, 'w', 'utf-8')
            for excludepath in job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']:
                gefile.write('%s\n' % excludepath)
            gefile.close()
        if 'objects' in job['physicalParams']['fileProtectionTypeParams'] and job['physicalParams']['fileProtectionTypeParams']['objects'] is not None and len(job['physicalParams']['fileProtectionTypeParams']['objects']) > 0:
            for obj in job['physicalParams']['fileProtectionTypeParams']['objects']:
                if 'filePaths' in obj and obj['filePaths'] is not None and len(obj['filePaths']) > 0:
                    print('    %s\n' % obj['name'])
                    ifilename = '%s-%s-includePaths.txt' % (job['name'], obj['name'])
                    ifile = codecs.open(ifilename, 'w', 'utf-8')
                    efilename = '%s-%s-excludePaths.txt' % (job['name'], obj['name'])
                    efile = codecs.open(efilename, 'w', 'utf-8')
                    for filepath in obj['filePaths']:
                        ifile.write('%s\n' % filepath['includedPath'])
                        if filepath['excludedPaths'] is not None and len(filepath['excludedPaths']) > 0:
                            for excludepath in filepath['excludedPaths']:
                                efile.write('%s\n' % excludepath)
                    ifile.close()
                    efile.close()
