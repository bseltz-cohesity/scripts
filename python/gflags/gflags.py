#!/usr/bin/env python
"""list gflags with python"""

# import pyhesity wrapper module
from pyhesity import *
import codecs
from time import sleep

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, default=None)
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-k', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-em', '--emailmfacode', action='store_true')
parser.add_argument('-s', '--servicename', type=str, default=None)
parser.add_argument('-n', '--flagname', type=str, default=None)
parser.add_argument('-f', '--flagvalue', type=str, default=None)
parser.add_argument('-r', '--reason', type=str, default=None)
parser.add_argument('-e', '--effectivenow', action='store_true')
parser.add_argument('-clear', '--clear', action='store_true')
parser.add_argument('-i', '--importfile', type=str, default=None)
parser.add_argument('-x', '--restartservices', action='store_true')

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clustername = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
emailmfacode = args.emailmfacode
servicename = args.servicename
flagname = args.flagname
flagvalue = args.flagvalue
reason = args.reason
effectivenow = args.effectivenow
importfile = args.importfile
clear = args.clear
restartservices = args.restartservices

# authentication =========================================================
# demand clustername if connecting to helios or mcm
if (mcm or vip.lower() == 'helios.cohesity.com') and clustername is None:
    print('-c, --clustername is required when connecting to Helios or MCM')
    exit(1)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode, emailMfaCode=emailmfacode)

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

cluster = api('get', 'cluster')


def setGflag(servicename, flagname, reason, flagvalue=None):

    if clear is True:
        print('Clearing %s: %s' % (servicename, flagname))
        gflag = {
            'serviceName': servicename,
            'gflags': [
                {
                    'name': flagname,
                    'clear': True,
                    'reason': reason
                }
            ],
            'effectiveNow': False
        }
    else:
        print('Setting %s: %s = %s' % (servicename, flagname, flagvalue))
        gflag = {
            'serviceName': servicename,
            'gflags': [
                {
                    'name': flagname,
                    'value': flagvalue,
                    'reason': reason
                }
            ],
            'effectiveNow': False
        }
    if effectivenow:
        gflag['effectiveNow'] = True
    response = api('put', '/clusters/gflag', gflag)
    sleep(1)


servicestorestart = []
servicescantrestart = []

# set a flag
if flagvalue is not None or clear is True:
    if servicename is None or flagname is None or reason is None:
        print('-servicename, -flagname, -flagvalue and -reason are all required to set a gflag')
        exit()
    else:
        setGflag(servicename=servicename, flagname=flagname, flagvalue=flagvalue, reason=reason)
        servicestorestart.append(servicename[1:].lower())

# import gflags fom export file
flagdata = []
if importfile is not None:
    f = codecs.open(importfile, 'r', 'utf-8')
    flagdata += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()
    for f in flagdata[1:]:
        (servicename, flagname, flagvalue, reason) = f.split(',', 3)
        flagvalue = flagvalue.replace(';;', ',')
        setGflag(servicename=servicename, flagname=flagname, flagvalue=flagvalue, reason=reason)
        if servicename.lower() != 'nexus':
            servicestorestart.append(servicename[1:].lower())
        else:
            servicescantrestart.append(servicename[1:].lower())

# write gflags to export file
print('\nCurrent GFlags:')
exportfile = 'gflags-%s.csv' % cluster['name']
f = codecs.open(exportfile, 'w', 'utf-8')
f.write('Service Name,Flag Name,Flag Value,Reason\n')

# get currrent flags
flags = api('get', '/clusters/gflag')

for service in flags:
    servicename = service['serviceName']
    print('\n%s:' % servicename)
    if 'gflags' in service:
        gflags = service['gflags']
        for gflag in gflags:
            flagname = gflag['name']
            flagvalue = gflag['value']
            reason = gflag['reason']
            print('    %s: %s (%s)' % (flagname, flagvalue, reason))
            flagvalue = flagvalue.replace(',', ';;')
            f.write('%s,%s,%s,%s\n' % (servicename, flagname, flagvalue, reason))

f.close()

if restartservices is True:
    print('\nRestarting required services...\n')
    restartParams = {
        "clusterId": cluster['id'],
        "services": list(set(servicestorestart))
    }
    response = api('post', '/nexus/cluster/restart', restartParams)

if restartservices is True and len(servicescantrestart) > 0:
    print('\nCant restart services: %s\n' % ', '.join(servicescantrestart))

print('\nGflags saved to %s\n' % exportfile)
