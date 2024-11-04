# Restore All VMs from a Protection Job using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores all VMs from a Potection Job.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/massVMrestore/massVMrestore.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/massVMrestore/massVMrestore.json
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x massVMrestore.py
# End download commands
```

## Components

* [massVMrestore.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/massVMrestore/massVMrestore.py): the main python script
* [massVMrestore.json](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/massVMrestore/massVMrestore.json): example targets file
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place the files in a folder together, then we can edit the target configuration JSON file. In the JSON file, configure host-datastore target pairs like this:

```json
{
    "targets": [
        {
            "hostname": "esxi1.mydomain.net",
            "datastorename": "datastore1"
        },
        {
            "hostname": "esxi2.mydomain.net",
            "datastorename": "datastore2"
        }
    ]
}
```

Then we can run the script like so:

```bash
./massVMrestore.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -vc vcenter.mydomain.net -n 'VM Network'
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity logon username
* -d, --domain: Cohesity logon domain (defaults to local)
* -j, --jobname: Name of protectionJob to recover
* -vc, --vcentername: name of vcenter to connect to
* -t, --targets: name of json file (optional: defaults to massVMrestore.json)
* -f, --foldername: name of vSphere folder to restore to
* -n, --networkname: name of VM network to attach to
* -s, --suffix: suffix to apply to VM names (optional)
* -p, --poweron: power on the VMs (optional)
* -mf, --maxfull: max percent datastore usage (optional: defaults to 85)

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
