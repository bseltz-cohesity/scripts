#!/usr/bin/env python
"""backed up files list for python"""

# import pyhesity wrapper module
from pyhesity import *
import codecs
import argparse

# command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-t', '--tenant', type=str, default=None)
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)

args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
tenant = args.tenant
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

outfile = 'physicalBackupPathsReport.csv'
f = codecs.open(outfile, 'w')
f.write('"Cluster","Protection Group","Server","Directive File","Path Type","Path"\n')


def getCluster():

    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])
    jobs = api('get', 'data-protect/protection-groups?environments=kPhysical&isActive=true&isDeleted=false', v=2)

    if jobs is not None and 'protectionGroups' in jobs and jobs['protectionGroups'] is not None:
        for job in jobs['protectionGroups']:
            if job['physicalParams']['protectionType'] == 'kFile':
                print('  %s' % job['name'])
                if 'objects' in job['physicalParams']['fileProtectionTypeParams'] and job['physicalParams']['fileProtectionTypeParams']['objects'] is not None and len(job['physicalParams']['fileProtectionTypeParams']['objects']) > 0:
                    for obj in job['physicalParams']['fileProtectionTypeParams']['objects']:
                        print('    %s' % obj['name'])
                        if 'globalExcludePaths' in job['physicalParams']['fileProtectionTypeParams'] and job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths'] is not None and len(job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']) > 0:
                            for excludepath in job['physicalParams']['fileProtectionTypeParams']['globalExcludePaths']:
                                f.write('"%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], obj['name'], False, "Exclude", excludepath))
                        if 'metadataFilePath' in obj and obj['metadataFilePath'] is not None:
                            f.write('"%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], obj['name'], True, "Include", obj['metadataFilePath']))
                        if 'filePaths' in obj and obj['filePaths'] is not None and len(obj['filePaths']) > 0:
                            for filepath in obj['filePaths']:
                                f.write('"%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], obj['name'], False, "Include", filepath['includedPath']))
                                if 'excludedPaths' in filepath and filepath['excludedPaths'] is not None and len(filepath['excludedPaths']) > 0:
                                    for excludePath in filepath['excludedPaths']:
                                        f.write('"%s","%s","%s","%s","%s","%s"\n' % (cluster['name'], job['name'], obj['name'], False, "Exclude", excludePath))


for vip in vips:

    # authentication =========================================================
    apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, quiet=True)

    # exit if not authenticated
    if apiconnected() is False:
        print('authentication failed')
        continue

    # if connected to helios or mcm, select access cluster
    if mcm or vip.lower() == 'helios.cohesity.com':
        if clusternames is None or len(clusternames) == 0:
            clusternames = [c['name'] for c in heliosClusters()]
        for clustername in clusternames:
            heliosCluster(clustername)
            if LAST_API_ERROR() != 'OK':
                continue
            getCluster()
    else:
        getCluster()


f.close()
print('\nOutput saved to %s\n' % outfile)

f.close()
