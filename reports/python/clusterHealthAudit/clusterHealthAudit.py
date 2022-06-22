#!/usr/bin/env python
"""Cluster Info for python"""

# version 2021-11-21

### import pyhesity wrapper module
from pyhesity import *
import datetime
# import requests
import codecs
import os.path

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-of', '--outfolder', type=str, default='.')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
password = args.password
folder = args.outfolder
useApiKey = args.useApiKey

GiB = 1024 * 1024 * 1024


def output(mystring):
    print(mystring)
    f.write(mystring + '\n')


# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey)

if password is None:
    password = pw(vip=vip, username=username, domain=domain)

cluster = api('get', 'cluster')
# version = cluster['clusterSoftwareVersion'].split('_')[0]

dateString = datetime.datetime.now().strftime("%Y-%m-%d")
outfileName = '%s/%s-%s-clusterHealthAudit.txt' % (folder, dateString, cluster['name'])
f = codecs.open(outfileName, 'w', 'utf-8')

# cluster info
output('\nCLUSTER INFO:\n')

output('CLUSTER ID                        : %s' % cluster['id'])
output('CLUSTER NAME                      : %s' % cluster['name'])
output('CLUSTER INCARNATION ID            : %s' % cluster['incarnationId'])
output('CLUSTER CREATION TIME             : %s' % usecsToDate((cluster['createdTimeMsecs'] * 1000)))
output('CLUSTER IP Preference             : %s' % cluster['ipPreference'])
output('NODE COUNT                        : %s' % cluster['nodeCount'])
output('PRODUCT MODEL                     : %s' % cluster['hardwareInfo']['hardwareModels'][0])
output('SOFTWARE VERSION                  : %s' % cluster['clusterSoftwareVersion'])
output('DNS SERVERS                       : %s' % ', '.join(cluster['dnsServerIps']))
output('DOMAIN NAMES                      : %s' % ', '.join(cluster['domainNames']))
output('ENCRYPTION ENABLED                : %s' % cluster['encryptionEnabled'])
output('FAILURES TOLERATED                : %s' % cluster['metadataFaultToleranceFactor'])
output('FAILURES TOLERATED LEVEL          : %s' % cluster['faultToleranceLevel'])
output('NTP SERVERS INTERNAL              : %s' % cluster['ntpSettings']['ntpServersInternal'])
output('CLUSTER TYPE                      : %s' % cluster['clusterType'])
output('LANGUAGE/LOCALE                   : %s' % cluster['languageLocale'])
output('TIMEZONE                          : %s' % cluster['timezone'])
output('ACTIVE MONITORING ENABLED         : %s' % cluster['enableActiveMonitoring'])
output('DISABLE SMB FOR ACTIVE DIR        : %s' % cluster['smbAdDisabled'])
output('CLUSTER AUDIT ENABLED             : %s' % cluster['clusterAuditLogConfig']['enabled'])
output('CLUSTER AUDIT RETENTION (DAYS)    : %s' % cluster['clusterAuditLogConfig']['retentionPeriodDays'])
output('FILER AUDIT ENABLED               : %s' % cluster['filerAuditLogConfig']['enabled'])
output('FILER AUDIT RETENTION (DAYS)      : %s' % cluster['filerAuditLogConfig']['retentionPeriodDays'])

# sd info
output('\nSTORAGE DOMAINS:\n')
viewboxes = api('get', 'viewBoxes?fetchStats=true')

for sd in viewboxes:
    output('STORAGE DOMAIN ID                 : %s' % sd['id'])
    output('STORAGE DOMAIN NAME               : %s' % sd['name'])
    output('CLUSTER PARTITION ID              : %s' % sd['clusterPartitionId'])
    output('CLUSTER PARTITION NAME            : %s' % sd['clusterPartitionName'])
    output('REMOVAL STATE                     : %s' % sd['removalState'])
    # output('TREAT FILE SYNC AS DATA SYNC  :  true
    output('DEDUPLICATION ENABLED             : %s' % sd['storagePolicy']['deduplicationEnabled'])
    output('INLINE DEDUPLICATION ENABLED      : %s' % sd['storagePolicy']['inlineDeduplicate'])
    output('DEDUP COMPRESSION DELAY SECS      : %s' % sd['storagePolicy']['deduplicateCompressDelaySecs'])
    # output('DOWNTIER THRESHOLD SECONDS    :  -
    output('ENCRYPTION POLICY                 : %s' % sd['storagePolicy']['encryptionPolicy'])
    output('COMPRESSION                       : %s' % sd['storagePolicy']['compressionPolicy'])
    output('INLINE COMPRESSION ENABLED        : %s' % sd['storagePolicy']['inlineCompress'])
    output('NUMBER OF DISK FAILURES TOLERATED : %s' % sd['storagePolicy']['numFailuresTolerated'])
    output('NUMBER OF NODE FAILURES TOLERATED : %s' % sd['storagePolicy']['numNodeFailuresTolerated'])
    output('S3 BUCKETS ALLOWED                : %s' % sd['s3BucketsAllowed'])
    output('STATISTICS                        :')
    # output('    READ IOS                      : -')
    # output('    WRITE IOS                     : -')
    # output('    BYTES READ                    : -')
    # output('    BYTES WRITTEN                 : -')
    # output('    READ LATENCY (ms)             : -')
    # output('    WRITE LATENCY (ms)            : -')
    output('    PHYSICAL SPACE USED           : %s' % round(float(sd['stats']['usagePerfStats']['totalPhysicalUsageBytes'] / (1024 * 1024 * 1024)), 1))
    output('    TOTAL RAW SPACE USED          : -')
    output('    PHYSICAL CAPACITY             : %s' % round(float(sd['stats']['usagePerfStats']['physicalCapacityBytes'] / (1024 * 1024 * 1024)), 1))
    output('    TOTAL RAW CAPACITY            : %s' % round(float(sd['stats']['usagePerfStats']['systemCapacityBytes'] / (1024 * 1024 * 1024)), 1))
    output('    PHYSICAL USED PERCENTAGE      : %s' % round(float(100 * sd['stats']['usagePerfStats']['totalPhysicalUsageBytes'] / sd['stats']['usagePerfStats']['physicalCapacityBytes']), 2))
    output('')

# interfaces
output('INTERFACES:')
interfaces = api('get', 'interface?cache=true')
if 'body' in interfaces:
    interfaces = interfaces['body']
for node in interfaces:
    output('')
    output('NODE ID                       : %s' % node['nodeId'])
    output('CHASSIS NAME                  : %s' % node['chassisSerial'])
    output('NODE SLOT NUMBER              : %s' % node['slot'])
    for intf in node['interfaces']:
        output('')
        output('    INTERFACE NAME            : %s' % intf['name'])
        if 'group' in intf:
            output('    INTERFACE GROUP           : %s' % intf['group'])
        output('    BONDING MODE              : %s' % intf['bondingMode'])
        if 'bondSlaves' in intf:
            for slave in intf['bondSlaves']:
                output('    BOND SLAVE                : %s' % slave)
        if 'macAddress' in intf:
            output('    INTERFACE MAC ADDRESS     : %s' % intf['macAddress'])
        output('    INTERFACE MTU             : %s' % intf['mtu'])
        output('    DEFAULT ROUTE             : %s' % intf['isDefaultRoute'])
        output('    INTERFACE ROLE            : %s' % intf['role'])
        output('    INTERFACE SPEED           : %s' % intf['speed'])
        output('    INTERFACE LINK UP         : %s' % intf['isConnected'])
        if 'services' in intf:
            output('    INTERFACE SERVICES        : %s' % ', '.join(intf['services']))

# gflags
output('\nGFLAGS:')

gflagfileName = '%s/%s-%s-gflags.csv' % (folder, dateString, cluster['name'])
writeheader = True
if os.path.exists(gflagfileName):
    writeheader = False
g = codecs.open(gflagfileName, 'a', 'utf-8')
if writeheader is True:
    g.write('Cluster,Service,gFlag,Value,Reason\n')

flags = api('get', '/nexus/cluster/list_gflags')
for service in flags['servicesGflags']:
    servicename = service['serviceName']
    if len(service['gflags']) > 0:
        output('\n%s:\n' % servicename)
    gflags = service['gflags']
    for gflag in gflags:
        flagname = gflag['name']
        flagvalue = gflag['value']
        reason = gflag['reason']
        output('    %s: %s (%s)' % (flagname, flagvalue, reason))
        g.write('"%s","%s","%s","%s","%s"\n' % (cluster['name'], servicename, flagname, flagvalue, reason))
g.close()

output('')
f.close()
