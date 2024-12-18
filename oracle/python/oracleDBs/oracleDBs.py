#!/usr/bin/env python
"""Show Oracle Databased Using Python"""

### import pyhesity wrapper module
from pyhesity import *
import codecs

### command line arguments
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
parser.add_argument('-x', '--unit', type=str, choices=['KiB', 'MiB', 'GiB', 'TiB'], default='GiB')

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
unit = args.unit

multiplier = 1024 * 1024 * 1024
if unit == 'TiB':
    multiplier = 1024 * 1024 * 1024 * 1024
elif unit == 'MiB':
    multiplier = 1024 * 1024
elif unit == 'KiB':
    multiplier = 1024

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

sources = api('get', 'protectionSources?environments=kOracle')
if sources is None or len(sources) == 0 or 'nodes' not in sources[0] or sources[0]['nodes'] is None or len(sources[0]['nodes']) == 0:
    print('\nNo Oracle sources found on this cluster\n')
    exit()

cluster = api('get', 'cluster')
outfile = 'oracleDBs-%s.csv' % cluster['name']
f = codecs.open(outfile, 'w')

# headings
f.write('"Cluster Name","Server Name","Database Name","Size (%s)","UUID","Version","Protected","DB Type","BCT Enabled","TDE Enabled","Archive Log Enabled","FRA Size (%s)","SGA Target","Shared Pool","Oracle Home"\n' % (unit, unit))

for server in sources[0]['nodes']:
    servername = server['protectionSource']['name']
    if 'applicationNodes' not in server or server['applicationNodes'] is None or len(server['applicationNodes']) == 0:
        continue
    print('\n%s' % servername)
    for db in server['applicationNodes']:
        # display(db)
        dbname = db['protectionSource']['name']
        dbsize = round(db.get('logicalSize', 0) / multiplier, 1)
        dbprotected = False
        if db['protectedSourcesSummary'][0].get('leavesCount', 0) > 0:
            dbprotected = True
        dbuuid = db['protectionSource']['oracleProtectionSource'].get('uuid', '')
        dbversion = db['protectionSource']['oracleProtectionSource'].get('version', '')
        dbtype = db['protectionSource']['oracleProtectionSource'].get('dbType', '')
        bct = db['protectionSource']['oracleProtectionSource'].get('bctEnabled', '')
        tdeCount = db['protectionSource']['oracleProtectionSource'].get('tdeEncryptedTsCount', 0)
        tdeEnabled = False
        if tdeCount > 0:
            tdeEnabled = True
        arch = db['protectionSource']['oracleProtectionSource'].get('archiveLogEnabled', '')
        fra = round(int(db['protectionSource']['oracleProtectionSource'].get('fraSize', 0)) / multiplier, 1)
        sga = db['protectionSource']['oracleProtectionSource'].get('sgaTargetSize', 0)
        shared = db['protectionSource']['oracleProtectionSource'].get('sharedPoolSize', 0)
        home = ''
        try:
            home = db['protectionSource']['oracleProtectionSource']['hosts'][0]['sessions'][0]['location']
        except Exception:
            pass
        print('    %s (%s) %s %s' % (dbname, dbuuid, dbsize, unit))
        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'],
                                                                                                  servername,
                                                                                                  dbname,
                                                                                                  dbsize,
                                                                                                  dbuuid,
                                                                                                  dbversion,
                                                                                                  dbprotected,
                                                                                                  dbtype,
                                                                                                  bct,
                                                                                                  tdeEnabled,
                                                                                                  arch,
                                                                                                  fra,
                                                                                                  sga,
                                                                                                  shared,
                                                                                                  home))
f.close()
print('\nOutput saved to %s\n' % outfile)
