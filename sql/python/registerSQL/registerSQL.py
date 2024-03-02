#!/usr/bin/env python

from pyhesity import *
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)           # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')   # admin user to do the work
parser.add_argument('-d', '--domain', type=str, default='local')      # domain of admin user
parser.add_argument('-s', '--servername', action='append', type=str)  # server name to register
parser.add_argument('-l', '--serverlist', type=str, default=None)     # text list of servers to register

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
servernames = args.servername
serverlist = args.serverlist

# authenticate
apiauth(vip, username, domain)

# read server file
if servernames is None:
    servernames = []
if serverlist is not None:
    f = open(serverlist, 'r')
    servernames += [s.strip() for s in f.readlines() if s.strip() != '']
    f.close()

sources = api('get', 'protectionSources/registrationInfo')

for servername in servernames:
    existingServer = [s for s in sources['rootNodes'] if s['rootNode']['name'].lower() == servername.lower()]
    if len(existingServer) > 0:
        register = True
        if 'applications' in existingServer[0]:
            existingApplication = [a for a in existingServer[0]['applications'] if a['environment'] == 'kSQL']
            if len(existingApplication) > 0:
                # already registered as SQL
                print('%s is already registered as a SQL Server' % servername)
                register = False
        if register is True:
            # register as SQL
            regSQLParams = {
                'ownerEntity': {
                    "id": existingServer[0]['rootNode']['id']
                },
                'appEnvVec': [3]
            }
            print('registereing %s as SQL Server' % servername)
            result = api('post', '/applicationSourceRegistration', regSQLParams)
    else:
        # not registered as phyiscal
        print('%s is not registered as a physical server' % servername)
