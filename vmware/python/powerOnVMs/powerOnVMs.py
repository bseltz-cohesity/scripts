#!/usr/bin/env python

# ./powerOnVMs.py -vc vcenter67.seltzer.net -vms 'alma9a, alma9b'

import ssl
from pyhesity import *
from pyVim import connect
from pyVmomi import vim
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-vc', '--vcenter', type=str, required=True)
parser.add_argument('-vu', '--vusername', type=str, default='administrator@vsphere.local')
parser.add_argument('-vp', '--vpassword', type=str, default=None)
parser.add_argument('-vms', '--vms', type=str, required=True)

args = parser.parse_args()

vCenter = args.vcenter
vCenterUsername = args.vusername
vCenterPwd = args.vpassword
vmlist = args.vms

if vCenterPwd is None:
    vCenterPwd = pw(vip=vCenter, username=vCenterUsername)

# Disable SSL certificate verification
sslContext = ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)
sslContext.check_hostname = False
sslContext.verify_mode = ssl.CERT_NONE

vcenter = connect.SmartConnect(host=vCenter,
                               user=vCenterUsername,
                               pwd=vCenterPwd,
                               sslContext=sslContext)

if not vcenter:
    print("\nFailed to connect to vcenter!")
    exit(1)

content = vcenter.RetrieveContent()
container = content.viewManager.CreateContainerView(
    content.rootFolder, [vim.VirtualMachine], True
)
vms = container.view

myvms = [v.strip() for v in vmlist.split(',')]

for vm in myvms:
    thisvm = [v for v in vms if v.name.lower() == vm.lower()]
    if thisvm is None or len(thisvm) == 0:
        print('vm %s not found' % vm)
    else:
        print('powering on %s' % thisvm[0].name)
        thisvm[0].PowerOnVM_Task()
