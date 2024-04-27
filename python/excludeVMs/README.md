# Apply Exclusion Rules to VM Autoprotect Protection Job using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script applies exclusions to an autoprotect VM protection job.

## Components

* [excludeVMs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMs.py): the main python script (one job only)
* [excludeVMsAllJobs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMsAllJobs.py): alternate script (all jobs)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module
* pyVmomi: Python SDK for the VMware vSphere API (see attribution below)

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMsAllJobs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/pyVmomi.tar.gz
tar -xvf pyVmomi.tar.gz
chmod +x excludeVMs.py
chmod +x excludeVMsAllJobs.py
# end download commands
```

To set exclusions for a single job:

```bash
# exclude templates, powered off vms, and vms that contain sql or ora from 'VM Backup' job
./excludeVMs.py -v mycluster -u myuser -d mydomain.net -j 'VM Backup' -xt -x sql -x ora -xp -vu administrator@vsphere.local -vp swordfish
# end
```

or to set exclusions for all jobs:

```bash
# exclude templates, powered off vms, and vms that contain sql or ora from all jobs
./excludeVMsAllJobs.py -v mycluster -u myuser -d mydomain.net -xt -x sql -x ora -xp -vu administrator@vsphere.local -vp swordfish
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
* -j, --jobname: name of protection job
* -xt, --excludeTemplates: (optional) exclude templates or not
* -x, --exclude: (optional) substring to exclude (repeat this parameter for multiple substrings)
* -xp, --excludePoweredOff: (optional) exclude powered off VMs
* -vu, --vcenterUserName: (optional) vCenter username
* -vp, --vcenterPassword: (optional) vCenter password

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

### Attributions

Thanks to VMware for the pyVmomi Python SDK for the VMware vSphere API. Located here: https://github.com/vmware/pyvmomi

I'm using pyVmomi here to query vCenter for the powerState of VMs.

Normally I would advise users to do a proper install of pyVmomi, which would allow the excludeVMs script to work fine, but there's a strong likelihood of excludeVMs being deployed onto a Cohesity cluster to run in a scheduled fashion, and I wouldn't advise installing pyVmomi on a Cohesity cluster (it might get wiped out during a Cohesity upgrade). So, I've decided to deliver pyVmomi as part of this script in portable form.  
