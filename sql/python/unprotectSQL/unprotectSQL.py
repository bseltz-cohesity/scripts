#!/usr/bin/env python
"""remove SQL servers, instances or databases from a protection group"""

from pyhesity import *
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
parser.add_argument('-j', '--jobname', type=str, required=True)
parser.add_argument('-s', '--servername', action='append', default=[])
parser.add_argument('-l', '--serverlist', type=str, default=None)
parser.add_argument('-in', '--instancename', action='append', default=[])
parser.add_argument('-db', '--dbname', action='append', default=[])
parser.add_argument('-dl', '--dblist', type=str, default=None)
parser.add_argument('-x', '--deletejobifempty', action='store_true')

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
jobname = args.jobname
instancenames = args.instancename
deletejobifempty = args.deletejobifempty


# gather list from command line params and file
def gatherList(param=None, filePath=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filePath is not None:
        try:
            with open(filePath, 'r') as f:
                items += [i.strip() for i in f.read().splitlines() if i.strip() != '']
        except Exception:
            print('Text file %s not found!' % filePath)
            exit(1)
    if required is True and len(items) == 0:
        print('No %s specified' % name)
        exit(1)
    return sorted(set(items))


serversToRemove = gatherList(args.servername, args.serverlist, name='servers', required=True)
dbsToRemove = gatherList(args.dbname, args.dblist, name='databases', required=False)

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

# get the protection job
jobs = api('get', 'data-protect/protection-groups', v=2)
job = None
if jobs is not None and 'protectionGroups' in jobs:
    matches = [j for j in jobs['protectionGroups'] if j['name'].lower() == jobname.lower()]
    if len(matches) > 0:
        job = matches[0]
if job is None:
    print("Protection group '%s' not found!" % jobname)
    exit(1)
if job['environment'] != 'kSQL':
    print("Protection group '%s' is not a SQL Server protection group!" % jobname)
    exit(1)

paramName = {
    'kFile': 'fileProtectionTypeParams',
    'kVolume': 'volumeProtectionTypeParams',
    'kNative': 'nativeProtectionTypeParams'
}
params = job['mssqlParams'][paramName[job['mssqlParams']['protectionType']]]

if 'excludeFilters' not in params or params['excludeFilters'] is None:
    params['excludeFilters'] = []
if 'objects' not in params or params['objects'] is None:
    params['objects'] = []

changesMade = False

# root SQL source
sources = api('get', 'protectionSources/registrationInfo?environments=kSQL&includeApplicationsTreeInfo=false')


def isSelected(thisSource):
    sourceId = thisSource['protectionSource']['id']
    return len([o for o in params['objects'] if o['id'] == sourceId]) > 0


def dropId(sourceId):
    params['objects'] = [o for o in params['objects'] if o['id'] != sourceId]


def removeSelection(thisSource):
    """remove a source, and any of its (grand)children, from the job's explicit
    selection list. Returns True if anything was actually removed."""
    global changesMade
    beforeCount = len(params['objects'])
    dropId(thisSource['protectionSource']['id'])
    if 'applicationNodes' in thisSource:
        for instance in thisSource['applicationNodes']:
            dropId(instance['protectionSource']['id'])
            if 'nodes' in instance:
                for node in instance['nodes']:
                    dropId(node['protectionSource']['id'])
    if 'nodes' in thisSource:
        for node in thisSource['nodes']:
            dropId(node['protectionSource']['id'])
    if len(params['objects']) < beforeCount:
        changesMade = True
        return True
    return False


def addExclusion(filterString):
    """add (or refresh) an exclusion filter, used when an item is auto-protected by a parent selection"""
    global changesMade
    existing = [f for f in params['excludeFilters'] if f['filterString'] == filterString]
    params['excludeFilters'] = [f for f in params['excludeFilters'] if f['filterString'] != filterString]
    params['excludeFilters'].append({'filterString': filterString, 'isRegularExpression': False})
    if len(existing) == 0:
        changesMade = True


def getInstanceSource(serverSource, instance):
    if 'nodes' in serverSource:
        # 7.3 AAG
        nodes = serverSource['nodes']
    else:
        nodes = serverSource.get('applicationNodes', [])
    matches = [n for n in nodes if n['protectionSource']['name'].lower() == instance.lower()]
    return matches[0] if len(matches) > 0 else None


for servername in serversToRemove:
    serverSourceRootNode = [n for n in sources['rootNodes'] if n['rootNode']['name'].lower() == servername.lower()]
    if len(serverSourceRootNode) == 0:
        print('Server %s not found!' % servername)
        continue
    serverSource = api('get', 'protectionSources?id=%s' % serverSourceRootNode[0]['rootNode']['id'])
    if isinstance(serverSource, list):
        serverSource = serverSource[0]
    # exclusion filters are case sensitive, so always use the source's exact registered name
    exactServerName = serverSource['protectionSource']['name']

    if len(instancenames) == 0 and len(dbsToRemove) == 0:
        # remove the entire server from the job. If the server itself isn't explicitly
        # selected, this still unselects any of its child instances/databases that are.
        if removeSelection(serverSource):
            print('Removing %s (and any selected child instances/databases) from protection' % servername)
        else:
            print('%s is not currently protected by this job' % servername)
    elif len(dbsToRemove) == 0:
        # remove one or more instances
        for instance in instancenames:
            instanceSource = getInstanceSource(serverSource, instance)
            if instanceSource is None:
                print('Instance %s not found on server %s' % (instance, servername))
                continue
            if isSelected(serverSource):
                # the instance is only protected because the whole server is selected (auto-protection)
                exactInstanceName = instanceSource['protectionSource']['name']
                addExclusion('%s/%s/' % (exactServerName, exactInstanceName))
                print('Excluding %s/%s (auto-protected via %s selection)' % (exactServerName, exactInstanceName, exactServerName))
            else:
                # if the instance itself isn't explicitly selected, this still unselects
                # any of its child databases that are
                if removeSelection(instanceSource):
                    print('Removing %s/%s (and any selected child databases) from protection' % (servername, instance))
                else:
                    print('%s/%s is not currently protected by this job' % (servername, instance))
    else:
        # remove one or more databases
        instancesToProcess = instancenames if len(instancenames) > 0 else ['MSSQLSERVER']
        for instance in instancesToProcess:
            instanceSource = getInstanceSource(serverSource, instance)
            if instanceSource is None:
                print('Instance %s not found on server %s' % (instance, servername))
                continue
            for thisDBName in dbsToRemove:
                dbFullName = '%s/%s' % (instanceSource['protectionSource']['name'], thisDBName)
                dbMatches = [n for n in instanceSource.get('nodes', []) if n['protectionSource']['name'].lower() == dbFullName.lower()]
                if len(dbMatches) == 0:
                    print('%s not found in %s/%s' % (thisDBName, servername, instance))
                    continue
                dbSource = dbMatches[0]
                if isSelected(serverSource) or isSelected(instanceSource):
                    # the database is only protected because a parent (server or instance) is selected (auto-protection).
                    # dbSource name is already "<exact instance name>/<exact db name>"
                    exactFilterString = '%s/%s' % (exactServerName, dbSource['protectionSource']['name'])
                    addExclusion(exactFilterString)
                    print('Excluding %s (auto-protected via parent selection)' % exactFilterString)
                else:
                    if removeSelection(dbSource):
                        print('Removing %s/%s/%s from protection' % (servername, instance, thisDBName))
                    else:
                        print('%s/%s/%s is not currently protected by this job' % (servername, instance, thisDBName))

if changesMade is False:
    print('No changes made. Exiting without committing changes.')
    exit(1)

if len(params['objects']) == 0:
    if deletejobifempty is True:
        print('Last object removed. Deleting %s...' % jobname)
        api('delete', 'data-protect/protection-groups/%s?deleteSnapshots=false' % job['id'], v=2)
        exit(0)
    else:
        print("Can't delete last object from %s. Canceling changes." % jobname)
        exit(1)

print('Updating job %s...' % jobname)
api('put', 'data-protect/protection-groups/%s' % job['id'], job, v=2)
