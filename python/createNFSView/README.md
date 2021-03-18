# Create an NFS View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a new SMB View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/createNFSView/createNFSView.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/createNFSView/pyhesity.py
chmod +x createNFSView.py
```

## Components

* createNFSView.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./createNFSView.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -n newview1 \
                   -q 'TestAndDev High' \
                   -s mystoragedomain \
                   -w '192.168.1.0, 255.255.255.0' \
                   -w 192.168.2.11 \
                   -l 300 \
                   -a 250
#end example
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity username
* -d, --domain: (optional) Active Directory domain (defaults to 'local')
* -n, --viewname: name of new view to create
* -q, --qospolicy: (optional) 'Backup Target Low', 'Backup Target High' or 'TestAndDev Low' (default is 'TestAndDev High')
* -s, --storageDomain: (optional) name of storage domain to place view data (default is DefaultStorageDomain)
* -w, --whitelist: (optional) ip (and optional netmask) to whitelist (can be used multiple times) e.g. '192.168.1.0, 255.255.255.0'
* -l, --quotalimit: (optional) quota limit in GiB
* -a --quotaalert: (optional) quota alert threshold in GiB (defaults to 90% of quotalimit)
