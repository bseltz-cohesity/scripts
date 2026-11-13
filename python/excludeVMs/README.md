# Exclude VMs from VMware Autoprotect Protection Groups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script adds (or removes) VM exclusions on VMware protection groups, using the Cohesity v2 protection group API. VMs can be selected by name, by a list of names, by regular expression, by substring, by being a template, or by being powered off.

## Components

* [excludeVMs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module
* pyVmomi: Python SDK for the VMware vSphere API (see attribution below)

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/excludeVMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/pyVmomi.tar.gz
tar -xvf pyVmomi.tar.gz
chmod +x excludeVMs.py
# end download commands
```

## Examples

Exclude templates, powered off VMs, and VMs that contain sql or ora from the 'VM Backup' group:

```bash
./excludeVMs.py -v mycluster -u myuser -d mydomain.net -j 'VM Backup' -xt -x sql -x ora -xp -vu administrator@vsphere.local -vp swordfish
```

Exclude templates, powered off VMs, and VMs that contain sql or ora from all VMware protection groups (omit `-j`):

```bash
./excludeVMs.py -v mycluster -u myuser -d mydomain.net -xt -x sql -x ora -xp -vu administrator@vsphere.local -vp swordfish
```

Exclude specific VMs by name from two groups:

```bash
./excludeVMs.py -v mycluster -u myuser -j 'VM Backup' -j 'VM Backup 2' -n mongodb -n oracle1
```

Exclude VMs listed in a text file (one name per line), or whose names match a regular expression:

```bash
./excludeVMs.py -v mycluster -u myuser -j 'VM Backup' -l ./vmlist.txt
./excludeVMs.py -v mycluster -u myuser -j 'VM Backup' -mt '^test-'
```

Remove exclusions for the selected VMs instead of adding them:

```bash
./excludeVMs.py -v mycluster -u myuser -j 'VM Backup' -n mongodb -r
```

Connect through Helios (the cluster name is required):

```bash
./excludeVMs.py -u myuser@mydomain.net -c mycluster -j 'VM Backup' -xt
```

Sample output:

```text
Excluding oracle1 from VM Backup (rule match)
Excluding mssql1 from VM Backup (rule match)
Excluding test1 from VM Backup (powered off)
Excluding centos7 from VM Backup (template)
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity (default is helios)
* -d, --domain: (optional) domain of username (default is local)
* -t, --tenant: (optional) organization to impersonate
* -c, --clustername: (optional) Helios/MCM cluster to connect to (required when connecting through Helios/MCM)
* -mcm, --mcm: (optional) connect through MCM
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key (will be prompted for and stored if omitted)
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Selection Parameters

* -j, --jobname: (optional) name of protection group to update (repeat for multiple groups). If omitted, all active VMware protection groups are updated
* -n, --vmname: (optional) name of a VM to exclude (repeat for multiple VMs)
* -l, --vmlist: (optional) text file of VM names to exclude, one per line
* -mt, --vmmatch: (optional) regular expression; VMs with matching names are excluded (case insensitive)
* -pm, --prefixmatch: (optional) anchor the --vmmatch expression to the start of the VM name
* -x, --exclude: (optional) substring of VM names to exclude (repeat for multiple substrings)
* -xt, --excludeTemplates: (optional) exclude VM templates
* -xp, --excludePoweredOff: (optional) exclude powered off VMs (requires -vu and -vp)
* -vu, --vcenterUserName: (optional) vCenter username (required for -xp)
* -vp, --vcenterPassword: (optional) vCenter password (required for -xp)
* -r, --removeexclusion: (optional) remove the exclusions for the selected VMs instead of adding them

At least one of -n, -l, -mt, -x, -xt or -xp must be specified.

## Notes

* Exclusions are applied to the `excludeObjectIds` list of each selected protection group. VMs that are already excluded are skipped, and a group is only updated if something changed.
* VMs are selected from all VMs in the group's vCenter, not only those under the objects the group protects. As a result, `-xt` and `-xp` will add every template or powered off VM in the vCenter to the exclusion list of each selected group, whether or not that group protects it.
* Template status comes from the Cohesity cluster. Power state is not available from the Cohesity API, so `-xp` queries vCenter directly using pyVmomi.

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
