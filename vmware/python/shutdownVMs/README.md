# Shutdown VMware VMs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs a graceful shutdown of the specified VMs, then monitors until the shutdowns are complete.

## Requirements

The script requires VMware tools to be running on the sepecified VMs. The script also requires the pyVmomi python module. It can be installed using pip:

```bash
python3 -m pip install pyVmomi
```

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/vmware/shutdownVMs/shutdownVMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x shutdownVMs.py
# end download commands
```

## Components

* [shutdownVMs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/pvmware/shutdownVMs/shutdownVMs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./shutdownVMs.py -vc myvcenter.mydomain.net \
                 -vu myusername@vsphere.local \
                 -vms 'vm1,vm2'
```

## Parameters

* -vc, --vcenter: FQDN of vCenter to connect to
* -vu, --vusername: (optional) default is <administrator@vsphere.local>
* -vp, --vpassword: (optional) will use cached password or will be prompted if omitted
* -vms, --vms: one or more VMs, comma separated, e.g. 'vm1,vm2'
