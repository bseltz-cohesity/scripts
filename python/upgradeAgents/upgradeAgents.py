#!/usr/bin/env python
"""Upgrade Cohesity Agents Using Python"""

### usage: ./upgradeAgents.py -v 192.168.1.198 -u admin [-d local]

### import pyhesity wrapper module
from pyhesity import *
from datetime import datetime
from time import sleep
import codecs

### command line arguments
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, default='helios.cohesity.com')
parser.add_argument('-u', '--username', type=str, default='helios')
parser.add_argument('-d', '--domain', type=str, default='local')
parser.add_argument('-c', '--clustername', type=str, action='append')
parser.add_argument('-mcm', '--mcm', action='store_true')
parser.add_argument('-i', '--useApiKey', action='store_true')
parser.add_argument('-pwd', '--password', type=str, default=None)
parser.add_argument('-np', '--noprompt', action='store_true')
parser.add_argument('-m', '--mfacode', type=str, default=None)
parser.add_argument('-o', '--ostype', type=str, default=None)
parser.add_argument('-x', '--execute', action='store_true')
parser.add_argument('-s', '--showcurrent', action='store_true')
parser.add_argument('-n', '--agentname', action='append', type=str)
parser.add_argument('-l', '--agentlist', type=str)
parser.add_argument('-k', '--skipwarnings', action='store_true')
parser.add_argument('-r', '--refresh', action='store_true')
parser.add_argument('-rt', '--timeout', type=int, default=35)
parser.add_argument('-w', '--sleeptime', type=int, default=60)
parser.add_argument('-t', '--throttle', type=int, default=12)

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
clusternames = args.clustername
mcm = args.mcm
useApiKey = args.useApiKey
password = args.password
noprompt = args.noprompt
mfacode = args.mfacode
ostype = args.ostype
showcurrent = args.showcurrent
execute = args.execute
agentnames = args.agentname
agentlist = args.agentlist
skipwarnings = args.skipwarnings
refresh = args.refresh
timeout = args.timeout
sleeptime = args.sleeptime
throttle = args.throttle


# gather server list
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


agentnames = gatherList(agentnames, agentlist, name='agents', required=False)

# authenticate
apiauth(vip=vip, username=username, domain=domain, password=password, useApiKey=useApiKey, helios=mcm, prompt=(not noprompt), mfaCode=mfacode)

# exit if not authenticated
if apiconnected() is False:
    print('authentication failed')
    exit(1)

now = datetime.now()
dateString = now.strftime("%Y-%m-%d-%H-%M-%S")

if mcm or vip.lower() == 'helios.cohesity.com':
    outfile = 'agentUpgrades-helios-%s.csv' % dateString
    if clusternames is None or len(clusternames) == 0:
        clusternames = [c['name'] for c in heliosClusters()]
else:
    cluster = api('get', 'cluster')
    clusternames = [cluster['name']]
    cluster = api('get', 'cluster')
    outfile = 'agentUpgrades-%s-%s.csv' % (cluster['name'], dateString)

f = codecs.open(outfile, 'w')
f.write('Cluster Name,Cluster Version,Agent Name,Agent Version,OS Type,OS Name,Status,Error Message\n')

reportNextSteps = False

for clustername in clusternames:
    print('\nConnecting to %s...\n' % clustername)
    if mcm or vip.lower() == 'helios.cohesity.com':
        heliosCluster(clustername)

    cluster = api('get', 'cluster')

    ### get Physical Servers
    nodes = api('get', 'protectionSources/registrationInfo?environments=kPhysical&environments=kHyperV&allUnderHierarchy=true')
    nodesCounted = 0
    if refresh is True:
        if nodes is not None and 'rootNodes' in nodes and nodes['rootNodes'] is not None:
            for node in nodes['rootNodes']:
                if 'physicalProtectionSource' in node['rootNode']:
                    paramkey = node['rootNode']['physicalProtectionSource']
                    hostType = paramkey['hostType'][1:]
                    osName = node['rootNode']['physicalProtectionSource']['osName']
                if 'hypervProtectionSource' in node['rootNode']:
                    paramkey = node['rootNode']['hypervProtectionSource']
                    osName = 'HyperV'
                    hostType = 'Windows'
                name = node['rootNode']['name']
                hostType = 'unknown'
                errorMessage = ''
                tenant = ''
                if 'entityPermissionInfo' in node['rootNode']:
                    if tenant in node['rootNode']['entityPermissionInfo']:
                        if 'name' in node['rootNode']['entityPermissionInfo']['tenant']:
                            tenant = node['rootNode']['entityPermissionInfo']['tenant']['name']
                try:
                    if 'authenticationErrorMessage' in node['registrationInfo'] and node['registrationInfo']['authenticationErrorMessage'] is not None:
                        errorMessage = node['registrationInfo']['authenticationErrorMessage'].split(',')[0].split('\n')[0]
                    if 'refreshErrorMessage' in node['registrationInfo'] and node['registrationInfo']['refreshErrorMessage'] is not None and node['registrationInfo']['refreshErrorMessage'] != '':
                        errorMessage = node['registrationInfo']['refreshErrorMessage'].split(',')[0].split('\n')[0]
                except Exception:
                    pass
                try:
                    hostType = paramkey['hostType'][1:]
                except Exception:
                    pass
                if len(agentnames) == 0 or name.lower() in [a.lower() for a in agentnames]:
                    if ostype is None or ostype.lower() == hostType.lower():
                        if errorMessage == '' or skipwarnings is False:
                            print('    Refreshing %s' % name)
                            if tenant != '':
                                impersonate(tenant)
                            result = api('post', 'protectionSources/refresh/%s' % node['rootNode']['id'])  # , timeout=timeout, quiet=True)
                            if tenant != '':
                                switchback()
        nodes = api('get', 'protectionSources/registrationInfo?environments=kPhysical&nodes=kHyperV&allUnderHierarchy=true')
        print('')

    if nodes is not None and 'rootNodes' in nodes and nodes['rootNodes'] is not None:
        for node in nodes['rootNodes']:
            tenant = ''
            agentIds = []  # list of agents to upgrade
            name = node['rootNode']['name']
            version = 'unknown'
            hostType = 'unknown'
            osName = 'unknown'
            status = 'unknown'
            errorMessage = ''
            errors = ''
            if 'physicalProtectionSource' in node['rootNode']:
                paramkey = node['rootNode']['physicalProtectionSource']
                hostType = paramkey['hostType'][1:]
                osName = node['rootNode']['physicalProtectionSource']['osName']
            if 'hypervProtectionSource' in node['rootNode']:
                paramkey = node['rootNode']['hypervProtectionSource']
                osName = 'HyperV'
                hostType = 'Windows'
                try:
                    thisSource = api('get', 'protectionSources?id=%s' % node['rootNode']['id'])
                    if thisSource is not None and len(thisSource) > 0:
                        if 'nodes' in thisSource[0] and thisSource[0]['nodes'] is not None and len(thisSource[0]['nodes']) > 0:
                            for thisNode in thisSource[0]['nodes']:
                                if thisNode['protectionSource']['hypervProtectionSource']['type'] in ['kHostGroup', 'kHostCluster', 'kHypervHost']:
                                    if 'nodes' in thisNode:
                                        nodes['rootNodes'].append({
                                            'rootNode': thisNode['protectionSource'],
                                            'nodes': thisNode['nodes']
                                        })
                                    else:
                                        nodes['rootNodes'].append({
                                            'rootNode': thisNode['protectionSource'],
                                        })
                except Exception:
                    pass
            if 'entityPermissionInfo' in node['rootNode']:
                if tenant in node['rootNode']['entityPermissionInfo']:
                    if 'name' in node['rootNode']['entityPermissionInfo']['tenant']:
                        tenant = node['rootNode']['entityPermissionInfo']['tenant']['name']
            try:
                if 'authenticationErrorMessage' in node['registrationInfo'] and node['registrationInfo']['authenticationErrorMessage'] is not None:
                    errorMessage = node['registrationInfo']['authenticationErrorMessage'].split(',')[0].split('\n')[0]
                if 'refreshErrorMessage' in node['registrationInfo'] and node['registrationInfo']['refreshErrorMessage'] is not None and node['registrationInfo']['refreshErrorMessage'] != '':
                    errorMessage = node['registrationInfo']['refreshErrorMessage'].split(',')[0].split('\n')[0]
            except Exception:
                pass
            if len(agentnames) == 0 or name.lower() in [a.lower() for a in agentnames]:
                if 'agents' in paramkey and paramkey['agents'] is not None and len(paramkey['agents']) > 0:
                    for agent in paramkey['agents']:
                        if 'version' in agent:
                            version = agent['version']
                        if 'upgradability' in agent and agent['upgradability'] is not None:
                            if agent['upgradability'] == 'kUpgradable':
                                status = 'upgradable'
                                agentIds.append(agent['id'])
                            else:
                                status = 'current'
                            break
                if ostype is None or ostype.lower() == hostType.lower():
                    if len(agentIds) > 0:
                        if errorMessage != '':
                            errors = '(warning: registration/refresh errors)'
                        if skipwarnings is not True or errors == '':
                            if execute is True:
                                status = 'upgrading'
                                print('    %s (%s): upgrading ...  %s' % (name, hostType, errors))
                                thisUpgrade = {'agentIds': agentIds}
                                if tenant != '':
                                    impersonate(tenant)
                                result = api('post', 'physicalAgents/upgrade', thisUpgrade)
                                nodesCounted += 1
                                if nodesCounted % throttle == 0:
                                    print('    sleeping for %s seconds' % sleeptime)
                                    sleep(sleeptime)
                                if tenant != '':
                                    switchback()
                            else:
                                print('    %s (%s): %s ***  %s' % (name, hostType, status, errors))
                                reportNextSteps = True
                    else:
                        if showcurrent is True or name.lower() in [a.lower() for a in agentnames]:
                            if 'agents' in paramkey:
                                print('    %s (%s): %s  %s' % (name, hostType, status, errors))
                f.write('%s,%s,%s,%s,%s,%s,%s,%s\n' % (cluster['name'], cluster['clusterSoftwareVersion'], name, version, hostType, osName, status, errorMessage))

if reportNextSteps is True:
    print('\nTo perform the upgrades, rerun the script with the -x (--execute) switch')

f.close()
print('\nOutput saved to %s\n' % outfile)
