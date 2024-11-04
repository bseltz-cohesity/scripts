#!/usr/bin/env python
"""base V1 example"""

# import pyhesity wrapper module
from pyhesity import *
# from datetime import datetime
import codecs

# command line arguments
import argparse
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

# outfile
outfile = 'nodeStatus.csv'
f = codecs.open(outfile, 'w', 'utf-8')
f.write('"Cluster Name","Host Name","Node ID","Node IP","Product Model","Software Version","App Node","Marked for Removal","In Cluster","Active Operation","message"\n')


def getNodeStatus():
    cluster = api('get', 'cluster/status')
    print('\n%s\n' % cluster['name'])
    nodes = api('get', 'nodes?includeMarkedForRemoval=true')
    for node in cluster['nodeStatuses']:
        thisnode = [n for n in nodes if n['id'] == node['id']][0]
        print('    %s' % thisnode['ip'])
        f.write('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' % (cluster['name'],
                                                                              thisnode['hostName'],
                                                                              thisnode['id'],
                                                                              thisnode['ip'],
                                                                              thisnode['productModel'],
                                                                              thisnode['nodeSoftwareVersion'],
                                                                              thisnode['isAppNode'],
                                                                              thisnode['isMarkedForRemoval'],
                                                                              node['inCluster'],
                                                                              node['activeOperation'],
                                                                              node['message']))


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
            getNodeStatus()
    else:
        getNodeStatus()


f.close()
print('\nOutput saved to %s\n' % outfile)
