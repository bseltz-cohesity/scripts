# Recover VMware VMs from CSV File using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script recovers VMs listed in a CSV file.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/recoverVMs-csv/recoverVMs-csv.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x recoverVMs-csv.py
# End download commands
```

## Components

* [recoverVMs-csv.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/recoverVMs-csv/recoverVMs-csv.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Create a CSV file with VMs you want to recover and their destinations, like so:

vm_name | vcenter | datacenter | host | folder | network | datastore
--- | --- | --- | --- | --- | --- | ---
myvm1 | myvcenter.mydomain.net | mydc | mycluster1 | /myfolder1 | my network1 | mydatastore1
myvm2 | myvcenter.mydomain.net | mydc | mycluster1 | /myfolder1 | my network1 | mydatastore1
myvm3 | myvcenter2.mydomain.net | mydc | mycluster2 | /myfolder2 | my network2 | mydatastore2

Place the files in a folder together, then we can run the script:

```bash
./recoverVMs-csv.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -csv myvms.csv \
                    -p
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -mfa, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -csv, --csvfile: path of CSV file to read
* -pre, --prefix: (optional) prefix to apply to VM name
* -p, --poweron: (optional) power on the VM
* -x, --detachnetwork: (optional) leave network disconnected
* -m, --preservemacaddress: (optional) keep same mac address
* -t, --recoverytype: (optional) InstantRecovery or CopyRecovery (default is InstantRecovery)
* -tn, --taskname: (optional) name of recovery task
* -coe, --continueonerror: (optional) continue if errors are encountered
* -dbg, --debug: (optional) print additional step-wise information
* -o, --overwrite: (optional) overwrite existing VM
* -k, --keepexistingvm: (optional) rename and keep existing VM
* -diff, --differentialrecovery: (optional) overwrite existing VM with differential recovery (works with CopyRecovery only)

## Specifying a Folder

You can specify a folder to restore to using any of the following formats:

* MyFolder/MySubFolder
* /MyFolder/MySubFolder
* MyDatacenter/vm/MyFolder/MySubFolder
* /MyDatacenter/vm/MyFolder/MySubFolder

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
