# Quick vCenter Authentication Test Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs a simple authentication to vCenter to test connectivity and credentials.

## Download the script

Run these commands to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/vCenterTest/vCenterTest.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/pyVmomi.tar.gz
tar -xvf pyVmomi.tar.gz
chmod +x vCenterTest.py
# End download commands
```

## Example

```bash
./vCenterTest.py  -vc vcenter.mydomain.net \
                  -vu administrator@vsphere.local \
                  -vp myvcpassword
```

## Parameters

* -vc, --vcenter: vcenter to connect to
* -vu, --viuser: vcenter username
* -vp, --vipassword: vcenter password (will prompt if omitted)

## Attributions

Thanks to VMware for the pyVmomi Python SDK for the VMware vSphere API. Located here: <https://github.com/vmware/pyvmomi>
