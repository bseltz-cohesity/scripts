# Apply Exclusion Rules to VM Autoprotect Job using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script applies exclusions to an autoprotect VM protection job and runs in the Cohesity EasyScript app.

You can download the script using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/excludeVMs/excludeVMsES.zip
# end download commands
```

Upload the zip file to easyScript and specify the arguments, like:

```bash
# exclude templates, powered off vms, and vms that contain sql or ora from 'VM Backup' job
-v mycluster -u myuser -d mydomain.net -p mypassword -j 'VM Backup' -xt -x sql -x ora -xp -vu administrator@vsphere.local -vp swordfish
# end
```

```text
adding oracle1 to exclusions (rule match)
adding mssql1 to exclusions (rule match)
adding test1 to exclusions (powered off)
addding centos7 to exclusions (template)
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -p, --password: password for Cohesity user
* -j, --jobname: name of protection job
* -xt, --excludeTemplates: (optional) exclude templates or not
* -x, --exclude: (optional) substring to exclude (repeat this parameter for multiple substrings)
* -xp, --excludePoweredOff: (optional) exclude powered off VMs
* -vu, --vcenterUserName: (optional) vCenter username
* -vp, --vcenterPassword: (optional) vCenter password

### Attributions

Thanks to VMware for the pyVmomi Python SDK for the VMware vSphere API. Located here: <https://github.com/vmware/pyvmomi>

I'm using pyVmomi here to query vCenter for the powerState of VMs.
