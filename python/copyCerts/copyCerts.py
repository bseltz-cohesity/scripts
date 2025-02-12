#!/usr/bin/env python

from pyhesity import *
import os
import codecs
import json
import getpass
import argparse
from time import sleep

parser = argparse.ArgumentParser()
parser.add_argument('-tc', '--targetcluster', type=str, required=True)
parser.add_argument('-tu', '--targetuser', type=str, required=True)
parser.add_argument('-td', '--targetdomain', type=str, default='local')
parser.add_argument('-sc', '--sourcecluster', type=str, default=None)
parser.add_argument('-su', '--sourceuser', type=str, default=None)
parser.add_argument('-sd', '--sourcedomain', type=str, default='local')
parser.add_argument('-m', '--promptformfacode', action='store_true')
parser.add_argument('-r', '--restore', action='store_true')
parser.add_argument('-k', '--useapikeys', action='store_true')

args = parser.parse_args()

targetcluster = args.targetcluster
targetuser = args.targetuser
targetdomain = args.targetdomain
sourcecluster = args.sourcecluster
sourceuser = args.sourceuser
sourcedomain = args.sourcedomain
promptformfacode = args.promptformfacode
restore = args.restore
useapikeys = args.useapikeys


# functions ----------------------------------------------------------------
def checkClusterVersion(cluster):
    if cluster['clusterSoftwareVersion'] < '6.8.1_u5':
        print('This script requires Cohesity version 6.8.1_u5 or later')
        exit()


def setGflag(vip, servicename='kMagneto', flagname='magneto_skip_cert_upgrade_for_multi_cluster_registration', flagvalue='false', reason='Enable agent certificate update'):

    gflagAlreadySet = False
    gflags = api('get', '/clusters/gflag')

    for service in gflags:
        svcName = service['serviceName']
        if svcName == servicename:
            serviceGflags = service['gflags']
            for serviceGflag in serviceGflags:
                if serviceGflag['name'] == flagname and serviceGflag['value'] == flagvalue:
                    print('Gflag already set')
                    gflagAlreadySet = True

    if gflagAlreadySet is False:
        print('Setting gflag  %s: %s = %s' % (servicename, flagname, flagvalue))
        gflag = {
            'serviceName': servicename,
            'gflags': [
                {
                    'name': flagname,
                    'value': flagvalue,
                    'reason': reason
                }
            ],
            'effectiveNow': True
        }
        response = api('put', '/clusters/gflag', gflag)


def copyCerts(certs):
    params = {
        "privateKey": certs['privateKey'],
        "caChain": certs['caChain']
    }
    result = api('post', 'cert-manager/bootstrap-ca', params, v=2)
    newCaChain = ''
    while certs['caChain'] != newCaChain:
        sleep(10)
        newcerts = api('get', 'cert-manager/ca-status', v=2)
        newCaChain = newcerts.get('caCertChain', '')


# main --------------------------------------------------------
if not sourceuser:
    sourceuser = targetuser
    sourcedomain = targetdomain

if restore is not True and not sourcecluster:
    print('Please specify --restore or --sourcecluster')
    exit()

if restore is not True:
    cacheFile = '%s-certs.json' % sourcecluster
    if os.path.exists(cacheFile):
        print('\nUsing cached certs from source cluster %s...' % sourcecluster)
        certs = json.loads(open(cacheFile, 'r').read())
    else:
        print('\nConnecting to source cluster %s...' % sourcecluster)
        mfacode = None
        if promptformfacode:
            mfacode = getpass.getpass("Please Enter MFA Code: ")
        apiauth(vip=sourcecluster, username=sourceuser, domain=sourcedomain, useApiKey=useapikeys, mfaCode=mfacode)

        cluster = api('get', 'cluster')

        # check cluster version
        checkClusterVersion

        # get certs
        print('Getting certs')
        certs = api('get', 'cert-manager/ca-keys', v=2)
        f = codecs.open(cacheFile, 'w')
        json.dump(certs, f)
        f.close()
        setGflag(vip=sourcecluster)

print('\nConnecting to target cluster %s...' % targetcluster)
mfacode = None
if promptformfacode:
    mfacode = getpass.getpass("Please Enter MFA Code: ")
apiauth(vip=targetcluster, username=targetuser, domain=targetdomain, useApiKey=useapikeys, mfaCode=mfacode)

cluster = api('get', 'cluster')

# check cluster version
checkClusterVersion

cacheFile = '%s-certs.json' % cluster['name']

# restore original certs
if restore:
    if os.path.exists(cacheFile):
        print('Restoring original certs')
        certs = json.loads(open(cacheFile, 'r').read())
        copyCerts(certs)
        print('Restore completed\n')
        exit()
    else:
        print('No backup found for %s\n' % sourcecluster)
        exit()

# backup original certs
origcerts = api('get', 'cert-manager/ca-keys', v=2)

if not os.path.exists(cacheFile):
    f = codecs.open(cacheFile, 'w')
    json.dump(certs, f)
    f.close()

# copy new certs
print('Copying certs')
copyCerts(certs)

# set gflag
setGflag(vip=targetcluster)
print('\nProcess finished\n')
