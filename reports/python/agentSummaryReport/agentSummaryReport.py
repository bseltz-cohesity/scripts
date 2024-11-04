#!/usr/bin/env python
"""Agent Summary Report version 2024.08.09 for Python"""

# import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
import codecs

# command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', action='append', type=str)
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', action='append', type=str)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-of', '--outfolder', type=str, default='.')
args = parser.parse_args()

vips = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
folder = args.outfolder

scriptVersion = '2024-08-09'

if vips is None or len(vips) == 0:
    vips = ['helios.cohesity.com']

now = datetime.now()
datestring = now.strftime("%Y-%m-%d-%H-%M-%S")
csvfileName = '%s/agentSummaryReport-%s.csv' % (folder, datestring)
csv = codecs.open(csvfileName, 'w', 'utf-8')
csv.write('"Cluster Name","Host","OS Type","Health","Cluster Version","Agent Version","Upgradability","Last Upgrade Status","Certificate Issuer","Certificate Status","Certificate Expiry"\n')


def getReport():
    cluster = api('get', 'cluster')
    print('\n%s' % cluster['name'])
    report = api('get', 'reports/agents')
    for agent in sorted(report, key=lambda h: h['hostIp']):
        print('    %s' % agent['hostIp'])
        csv.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'].upper(), agent['hostIp'], agent['hostOsType'], agent['healthStatus'], cluster['clusterSoftwareVersion'], agent['version'], agent['upgradability'], agent.get('lastUpgradeStatus', '-'), agent.get('certificateIssuer', '-'), agent.get('certificateStatus', '-'), usecsToDate(agent.get('certificateExpiryTimeUsecs', 0))))


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
            getReport()
    else:
        getReport()

csv.close()
print('\nOutput saved to %s\n' % csvfileName)
