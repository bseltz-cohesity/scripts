# Restore All VMs from a Protection Job using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores all VMs from a Potection Job.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/recoverVMjob/recoverVMjob.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x recoverVMjob.py
# End download commands
```

## Components

* recoverVMJob.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

```bash
./recoverVMjob.py -v mycluster -u admin -j 'VM Backup' -vc vcenter.mydomain.net -vh esxhost1.mydomain.net -ds datastore1 -n 'VM Network' -s recover -f myfolder
```

```text
Connected!
Recovering VM Backup...
Recovery Started...
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity logon username
* -d, --domain: Cohesity logon domain (defaults to local)
* -j, --jobname: Name of protectionJob to recover
* -vc, --vcentername: name of vcenter to connect to
* -vh, --vhost: name of vSphere host to restore to
* -ds, --datastorename: name of datastore to restore to
* -f, --foldername: name of vSphere folder to restore to
* -n, --networkname: name of VM network to attach to
* -s, --suffix: suffix to apply to VM names (optional)
* -p, --poweron: power on the VMs (optional)

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
