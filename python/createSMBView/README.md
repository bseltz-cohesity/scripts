# Create an SMB View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a new SMB View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/createSMBView/createSMBView.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x createSMBView.py
```

## Components

* [createSMBView.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/createSMBView/createSMBView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./createSMBView.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -n newview1 \
                   -w mydomain.net\server1 \
                   -f mydomain.net\admingroup1
                   -f mydomain.net\admingroup2 \
                   -r mydomain.net\auditors \
                   -q 'TestAndDev High' \
                   -s mystoragedomain \
                   -i '192.168.1.10, myserver' \
                   -i 192.168.1.11
#end example
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity username
* -d, --domain: (optional) Active Directory domain (defaults to 'local')
* -n, --viewname: name of new view to create
* -r, --readonly: principal to grant readonly access (can be used multiple times)
* -w, --readwrite: principal to grant read/write access (can be used multiple times)
* -f, --fullcontrol: principal to grant full control (can be used multiple times)
* -q, --qospolicy: defaults to 'Backup Target Low' or choose 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low'
* -s, --storageDomain: name of storage domain to place view data. Defaults to DefaultStorageDomain
* -i, --whitelist: ip (and optional description) address to whitelist (can be used multiple times)
