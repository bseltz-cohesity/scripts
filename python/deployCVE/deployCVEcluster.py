#!/usr/bin/env python

# from os import system, path
# from sys import exit
from threading import Thread
from time import sleep
from getpass import getpass
import tarfile
import urllib2
import ssl

from pyVim import connect
from pyVmomi import vim
from pyhesity import *
from datetime import datetime

### command line arguments
import argparse
parser = argparse.ArgumentParser()

parser.add_argument('-vc', '--vcenter', required=True)
parser.add_argument('-vu', '--viuser', required=True)
parser.add_argument('-vp', '--vipassword', default=None)
parser.add_argument('-dc', '--datacenter_name', default=None)
parser.add_argument('-ds', '--datastore_name', action='append', required=True)
parser.add_argument('-vh', '--host_name', action='append', default=None)
parser.add_argument('-f', '--ova_path', required=True)
parser.add_argument('-n', '--vmname', action='append', required=True)
parser.add_argument('-md', '--metasize', type=int, default=52)
parser.add_argument('-dd', '--datasize', type=int, default=250)
parser.add_argument('-n1', '--network1', default='VM Network')
parser.add_argument('-n2', '--network2', default='VM Network 2')
parser.add_argument('-ip', '--ip', action='append', required=True)
parser.add_argument('-m', '--netmask', required=True)
parser.add_argument('-g', '--gateway', required=True)
parser.add_argument('-v', '--vip', action='append', type=str, required=True)
parser.add_argument('-c', '--clustername', type=str, required=True)
parser.add_argument('-ntp', '--ntpserver', action='append', type=str, required=True)
parser.add_argument('-dns', '--dnsserver', action='append', type=str, required=True)
parser.add_argument('-e', '--encrypt', action='store_true')
parser.add_argument('-cd', '--clusterdomain', type=str, required=True)
parser.add_argument('-z', '--dnsdomain', action='append', type=str)
parser.add_argument('-rp', '--rotationalpolicy', type=int, default=90)
parser.add_argument('--fips', action='store_true')
parser.add_argument('-x', '--skipcreate', action='store_true')
parser.add_argument('-k', '--licensekey', type=str, default=None)
parser.add_argument('--accept_eula', action='store_true')


args = parser.parse_args()

if not args.vipassword:
    args.vipassword = getpass(prompt='Enter vcenter password: ')

nodeips = list(args.ip)
vmnames = list(args.vmname)
datastores = list(args.datastore_name)
cluster_names = list(args.host_name)
vips = list(args.vip)
clustername = args.clustername
ntpservers = list(args.ntpserver)
dnsservers = list(args.dnsserver)
encrypt = args.encrypt
clusterdomain = args.clusterdomain
dnsdomains = [clusterdomain]
if args.dnsdomain is not None:
    dnsdomains = [clusterdomain] + list(args.dnsdomain)
rotationalpolicy = args.rotationalpolicy
fips = args.fips
hostname = clustername + '.' + clusterdomain
skipcreate = args.skipcreate
licensekey = args.licensekey


def get_obj_in_list(obj_name, obj_list):
    """
    Gets an object out of a list (obj_list) whos name matches obj_name.
    """
    for o in obj_list:
        if o.name == obj_name:
            return o
    print("Unable to find object by the name of %s in list:\n%s" %
          (obj_name, map(lambda o: o.name, obj_list)))
    exit(1)


def get_objects(si, args):
    """
    Return a dict containing the necessary objects for deployment.
    """
    # Get datacenter object.
    datacenter_list = si.content.rootFolder.childEntity
    if args.datacenter_name:
        datacenter_obj = get_obj_in_list(args.datacenter_name, datacenter_list)
    else:
        datacenter_obj = datacenter_list[0]

    network_list = datacenter_obj.networkFolder.childEntity
    network_obj1 = get_obj_in_list(args.network1, network_list)
    network_obj2 = get_obj_in_list(args.network2, network_list)

    # Get datastore object.
    datastore_list = datacenter_obj.datastoreFolder.childEntity
    if args.datastore_name:
        datastore_obj = get_obj_in_list(args.datastore_name, datastore_list)
    elif len(datastore_list) > 0:
        datastore_obj = datastore_list[0]
    else:
        print("No datastores found in DC (%s)." % datacenter_obj.name)

    # Get cluster object.
    cluster_list = datacenter_obj.hostFolder.childEntity
    if args.cluster_name:
        cluster_obj = get_obj_in_list(args.cluster_name, cluster_list)
    elif len(cluster_list) > 0:
        cluster_obj = cluster_list[0]
    else:
        print("No clusters found in DC (%s)." % datacenter_obj.name)

    # Generate resource pool.
    resource_pool_obj = cluster_obj.resourcePool

    return {"datacenter": datacenter_obj,
            "datastore": datastore_obj,
            "resource pool": resource_pool_obj,
            "network1": network_obj1,
            "network2": network_obj2}


def keep_lease_alive(lease):
    """
    Keeps the lease alive while POSTing the VMDK.
    """
    while(True):
        sleep(5)
        try:
            lease.HttpNfcLeaseProgress(50)
            if (lease.state == vim.HttpNfcLease.State.done):
                return
        except Exception:
            return


def add_disk(vm, si, disk_size, disk_type, controller, unit_number):

    spec = vim.vm.ConfigSpec()
    dev_changes = []
    new_disk_kb = int(disk_size) * 1024 * 1024
    disk_spec = vim.vm.device.VirtualDeviceSpec()
    disk_spec.fileOperation = "create"
    disk_spec.operation = vim.vm.device.VirtualDeviceSpec.Operation.add
    disk_spec.device = vim.vm.device.VirtualDisk()
    disk_spec.device.backing = \
        vim.vm.device.VirtualDisk.FlatVer2BackingInfo()
    if disk_type == 'thin':
        disk_spec.device.backing.thinProvisioned = True
    disk_spec.device.backing.diskMode = 'independent_persistent'
    disk_spec.device.unitNumber = unit_number
    disk_spec.device.capacityInKB = new_disk_kb
    disk_spec.device.controllerKey = controller.key
    dev_changes.append(disk_spec)
    spec.deviceChange = dev_changes
    vm.ReconfigVM_Task(spec=spec)
    print("%sGB disk added to %s" % (disk_size, vm.config.name))


# validate parameters before proceeding
# do we have at least 3 ips?

if len(nodeips) < 3:
    print('not enough node ips specified!')
    exit(1)
if len(vmnames) != len(nodeips):
    print('number of vm names and ips does not match!')
    exit(1)
if len(datastores) != len(nodeips):
    print('number of datastores and vms does not match!')
    exit(1)
if len(cluster_names) != len(nodeips):
    print('number of hosts/clusters and vms does not match!')
    exit(1)

# extract ova file
t = tarfile.open(args.ova_path)
ovffilename = list(filter(lambda x: x.endswith(".ovf"), t.getnames()))[0]
ovffile = t.extractfile(ovffilename)
try:
    ovfd = ovffile.read()
except Exception:
    print("Could not read file: %s" % ovffile)
    exit(1)
ovffile.close()

# connect to vcenter
try:
    si = connect.SmartConnectNoSSL(host=args.vcenter,
                                   user=args.viuser,
                                   pwd=args.vipassword,
                                   port=443)
except Exception:
    print("Unable to connect to %s" % args.vcenter)
    exit(1)

for i, ip in enumerate(nodeips):
    print('Deploying OVA...')
    args.vmname = vmnames[i]
    args.datastore_name = datastores[i]
    args.cluster_name = cluster_names[i]

    objs = get_objects(si, args)

    manager = si.content.ovfManager

    spec_params = vim.OvfManager.CreateImportSpecParams()
    spec_params.entityName = args.vmname
    spec_params.networkMapping = [
        vim.OvfManager.NetworkMapping(name='DataNetwork', network=objs["network1"]),
        vim.OvfManager.NetworkMapping(name='SecondaryNetwork', network=objs["network2"])
    ]

    spec_params.propertyMapping = [
        vim.KeyValue(key='dataIp', value=ip),
        vim.KeyValue(key='dataNetmask', value=args.netmask),
        vim.KeyValue(key='dataGateway', value=args.gateway),
        vim.KeyValue(key='DeploymentOption', value='small'),
        vim.KeyValue(key='IpAssignment.IpProtocol', value='IPv4'),
        vim.KeyValue(key='NetworkMapping.DataNetwork', value=args.network1),
        vim.KeyValue(key='NetworkMapping.SecondaryNetwork', value=args.network2)
    ]

    import_spec = manager.CreateImportSpec(ovfd,
                                           objs["resource pool"],
                                           objs["datastore"],
                                           spec_params)

    lease = objs["resource pool"].ImportVApp(import_spec.importSpec,
                                             objs["datacenter"].vmFolder)

    # keep alive while OVA is being deployed
    ovabusy = True
    while(ovabusy):
        if lease.state == vim.HttpNfcLease.State.ready:
            keepalive_thread = Thread(target=keep_lease_alive, args=(lease,))
            keepalive_thread.start()

            for deviceUrl in lease.info.deviceUrl:
                url = deviceUrl.url.replace('*', args.vcenter)
                fileItem = list(filter(lambda x: x.deviceId == deviceUrl.importKey,
                                       import_spec.fileItem))[0]
                ovffilename = list(filter(lambda x: x == fileItem.path,
                                          t.getnames()))[0]
                ovffile = t.extractfile(ovffilename)
                headers = {'Content-length': ovffile.size}
                req = urllib2.Request(url, ovffile, headers)
                response = urllib2.urlopen(req, context=ssl._create_unverified_context())
            lease.HttpNfcLeaseComplete()
            keepalive_thread.join()
            ovabusy = False
        elif lease.state == vim.HttpNfcLease.State.error:
            print("Lease error: %s" % lease.error)
            exit(1)

    # add disks
    print('adding disks...')

    searcher = si.content.searchIndex
    vm = searcher.FindChild(objs['resource pool'], args.vmname)

    for dev in vm.config.hardware.device:
        if dev.deviceInfo.label == 'SCSI controller 1':
            controller1 = dev
        if dev.deviceInfo.label == 'SCSI controller 2':
            controller2 = dev

    add_disk(vm, si, args.metasize, 'thin', controller1, 0)
    add_disk(vm, si, args.datasize, 'thin', controller2, 0)

    # poweron
    print('powering on VM...')
    objs['datacenter'].PowerOnMultiVM_Task([vm])

    print('OVA Deployment Complete!')

# create cluster
print('waiting for nodes to come online...')
while apiconnected() is False:
    sleep(5)
    apiauth(nodeips[0], 'admin', 'local', password='admin', quiet=True)

### Cluster create parameters
ClusterBringUpReq = {
    "clusterName": clustername,
    "ntpServers": ntpservers,
    "dnsServers": dnsservers,
    "domainNames": dnsdomains,
    "clusterGateway": args.gateway,
    "clusterSubnetCidrLen": args.netmask,
    "ipmiGateway": None,
    "ipmiSubnetCidrLen": None,
    "ipmiUsername": None,
    "ipmiPassword": None,
    "enableEncryption": encrypt,
    "rotationalPolicy": rotationalpolicy,
    "enableFipsMode": fips,
    "nodes": [],
    "clusterDomain": clusterdomain,
    "hostname": hostname,
    "vips": vips
}

### gather node info
if skipcreate is not True:
    # wait for all requested nodes to be free
    nodecount = 0
    while nodecount < len(nodeips):
        nodecount = 0
        nodes = api('get', '/nexus/avahi/discover_nodes')
        for freenode in nodes['freeNodes']:
            if freenode['ipAddresses'][0] in nodeips:
                nodecount += 1
        # print("%s of %s free nodes found" % (nodecount, len(nodeips)))
        if nodecount < len(nodeips):
            sleep(10)

    for freenode in nodes['freeNodes']:
        for nodeip in nodeips:

            # gather node IP info
            if nodeip == freenode['ipAddresses'][0]:

                if 'ipAddresses' in freenode:
                    ip = freenode['ipAddresses'][0]
                else:
                    print('node %s has no IP address' % nodeid)
                    exit(1)

                if 'ipmiIp' in freenode:
                    ipmiip = freenode['ipmiIp']
                else:
                    print('node %s has no IPMI IP address' % nodeid)
                    exit(1)

                # add node to Cluster parameters
                node = {
                    "id": freenode['nodeId'],
                    "ip": freenode['ipAddresses'][0],
                    "ipmiIp": ""
                }

                ClusterBringUpReq['nodes'].append(node)

### create the cluster
if skipcreate is not True:
    print("Creating Cluster %s..." % clustername)
    result = api('post', '/nexus/cluster/virtual_robo_create', ClusterBringUpReq)

### wait for cluster to come online
print("Waiting for cluster creation...")
clusterId = None
while clusterId is None:
    sleep(5)
    apiauth(nodeips[0], 'admin', 'local', password='admin', quiet=True)
    if(apiconnected() is True):
        cluster = api('get', 'cluster', quiet=True)
        if cluster is not None:
            if 'errorCode' not in cluster:
                clusterId = cluster['id']

print("New Cluster ID is: %s" % clusterId)
apidrop()

### wait for services to be started
print("Waiting for services to start...")
synced = False
while synced is False:
    sleep(5)
    apiauth(nodeips[0], 'admin', 'local', password='admin', quiet=True)
    if(apiconnected() is True):
        stat = api('get', '/nexus/cluster/status', quiet=True)
        if stat is not None:
            if stat['isServiceStateSynced'] is True:
                synced = True
                print('Cluster Services are Started')

### accept eula and apply license key
if args.accept_eula is True and licensekey is not None:
    print("Accepting EULA and Applying License Key...")
    now = datetime.now()
    nowUsecs = dateToUsecs(now.strftime('%Y-%m-%d %H:%M:%S'))
    nowMsecs = int(round(nowUsecs / 1000000))
    agreement = {
        "signedVersion": 2,
        "signedByUser": "admin",
        "signedTime": nowMsecs,
        "licenseKey": licensekey
    }
    api('post', '/licenseAgreement', agreement)
print("Cluster Creation Successful!")
