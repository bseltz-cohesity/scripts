#!/usr/bin/env python

from pyhesity import *
from getpass import getpass
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
parser.add_argument('-n', '--servername', action='append', type=str)
parser.add_argument('-l', '--serverlist', type=str, default=None)
parser.add_argument('-cd', '--configdir', type=str, required=True)
parser.add_argument('-dc', '--datacenter', action='append', type=str)
parser.add_argument('-cl', '--commitlog', type=str, default=None)
parser.add_argument('-dd', '--dseconfigdir', type=str, default=None)
parser.add_argument('-dt', '--dsetieredstorage', action='store_true')
parser.add_argument('-da', '--dseauthenticator', action='store_true')
parser.add_argument('-dn', '--dsesolrnode', action='append', type=str)
parser.add_argument('-dp', '--dsesolrport', type=int, default=None)
parser.add_argument('-su', '--sshusername', type=str, required=True)
parser.add_argument('-sp', '--sshpassword', type=str, default=None)
parser.add_argument('-pp', '--promptforpassphrase', action='store_true')
parser.add_argument('-sk', '--sshprivatekeyfile', type=str, default=None)
parser.add_argument('-ju', '--jmxusername', type=str, default=None)
parser.add_argument('-jp', '--jmxpassword', type=str, default=None)
parser.add_argument('-cu', '--cassandrausername', type=str, default=None)
parser.add_argument('-cp', '--cassandrapassword', type=str, default=None)
parser.add_argument('-kp', '--kerberosprincipal', type=str, default=None)

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

servername = args.servername
serverlist = args.serverlist

datacenters = args.datacenter
configdir = args.configdir
commitlog = args.commitlog
dseconfigdir = args.dseconfigdir
dsetieredstorage = args.dsetieredstorage
dseauthenticator = args.dseauthenticator
dsesolrnodes = args.dsesolrnode
dsesolrport = args.dsesolrport

sshusername = args.sshusername
sshpassword = args.sshpassword
sshprivatekeyfile = args.sshprivatekeyfile
promptforpassphrase = args.promptforpassphrase
jmxusername = args.jmxusername
jmxpassword = args.jmxpassword
cassandrausername = args.cassandrausername
cassandrapassword = args.cassandrapassword
kerberosprincipal = args.kerberosprincipal

# gather list function
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


# get list of views to protect
servers = gatherList(servername, serverlist, name='servers', required=True)

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

if sshprivatekeyfile is not None:
    keyfilehandle = open(sshprivatekeyfile, 'r')
    sshprivatekey = keyfilehandle.read()
    if promptforpassphrase is True:
        sshpassword = getpass("\nEnter SSH passphrase: ")

if sshpassword is None and sshprivatekeyfile is None:
    sshpassword = getpass("\nEnter SSH password: ")

if jmxusername is not None and jmxpassword is None:
    jmxpassword = getpass("\nEnter JMX password: ")

if cassandrausername is not None and cassandrapassword is None:
    cassandrapassword = getpass("\nEnter cassandra password: ")

for server in servers:
    server = server.replace(' ', '')
    seeds = server.split(',')
    seedip = seeds[-1]
    sourcename = seeds[0]
    newSourceRegistration = True
    registeredSource = None
    registeredSources = api('get', 'protectionSources/registrationInfo?environments=kCassandra')
    if registeredSources is not None and 'rootNodes' in registeredSources and registeredSources['rootNodes'] is not None and len(registeredSources['rootNodes']) > 0:
        registeredSource = [r for r in registeredSources['rootNodes'] if r['rootNode']['cassandraProtectionSource']['uuid'].lower() == sourcename.lower() or r['rootNode']['customName'].lower() == sourcename.lower()]
    # display(registeredSource)
    # exit()
    if registeredSource is not None and len(registeredSource) > 0:
        sourceId = registeredSource[0]['rootNode']['id']
        newSourceRegistration = False
    newSource = {
        "environment": "kCassandra",
        "name": sourcename,
        "cassandraParams": {
            "seedNode": seedip,
            "configDirectory": configdir,
            "sshPasswordCredentials": {
                "username": sshusername,
                "password": sshpassword
            },
            "sshPrivateKeyCredentials": None,
            "jmxCredentials": None,
            "cassandraCredentials": None,
            "dataCenterNames": [],
            "commitLogBackupLocation": "",
            "dseConfigurationDirectory": dseconfigdir,
            "isDseAuthenticator": False,
            "isDseTieredStorage": False,
            "dseSolrInfo": None,
            "kerberosPrincipal": None
        }
    }
    if sshprivatekeyfile is not None:
        newSource['cassandraParams']['sshPasswordCredentials'] = None
        newSource['cassandraParams']['sshPrivateKeyCredentials'] = {
            "userId": sshusername,
            "privateKey": sshprivatekey,
            "passphrase": sshpassword
        }
    if kerberosprincipal is not None:
        newSource['cassandraParams']['kerberosPrincipal'] = kerberosprincipal
    if commitlog is not None:
        newSource['cassandraParams']['commitLogBackupLocation'] = commitlog
    if datacenters is not None and len(datacenters) > 0:
        newSource['cassandraParams']['dataCenterNames'] = datacenters
    if dseauthenticator is True:
        newSource['cassandraParams']['isDseAuthenticator'] = True
    if dsetieredstorage is True:
        newSource['cassandraParams']['isDseTieredStorage'] = True
    if dsesolrnodes is not None and len(dsesolrnodes) > 0:
        newSource['cassandraParams']['dseSolrInfo'] = {
            "solrNodes": dsesolrnodes,
            "solrPort": dsesolrport
        }
    if jmxusername is not None:
        newSource['cassandraParams']['jmxCredentials'] = {
            "username": jmxusername,
            "password": jmxpassword
        }
    if cassandrausername is not None:
        newSource['cassandraParams']['cassandraCredentials'] = {
            "username": cassandrausername,
            "password": cassandrapassword
        }
    if newSourceRegistration is True:
        result = api('post', 'data-protect/sources/registrations', newSource, v=2)
        if 'id' in result:
            print('Registering %s' % sourcename)
    else:
        result = api('put', 'data-protect/sources/registrations/%s' % sourceId, newSource, v=2)
        print('Updating %s' % sourcename)
