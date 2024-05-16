# Create an NFS View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates or updates an NFS View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createNFSView/createNFSView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x createNFSView.py
```

## Components

* [createNFSView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createNFSView/createNFSView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./createNFSView.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -n newview1 \
                   -s mystoragedomain \
                   -w '192.168.1.0, 255.255.255.0, Test Lab' \
                   -w 192.168.2.11
#end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multitenancy org name
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --viewname: name of new view to create or modify
* -q, --qospolicy: (optional) Name of QOS policy (e.g. 'TestAndDev High')
* -vt, --viewtemplate: (optional) name of view template (e.g. 'Applications Dump')
* -nv, --nfsversion: (optional) NFS version 3 or 4.1 (default is 4.1)
* -s, --storageDomain: (optional) name of storage domain to place view data (default is DefaultStorageDomain)
* -i, --caseinsensitive: (optional) make file and folder names case insensitive
* -w, --whitelist: (optional) ip (and optional netmask, description) to whitelist (can be used multiple times) e.g. '192.168.1.0, 255.255.255.0, Test Lab'
* -l, --quotalimit: (optional) quota limit in GiB
* -a, --quotaalert: (optional) quota alert threshold in GiB (defaults to 90% of quotalimit)
* -r, --removewhitelistentries: (optional) remove specified entries from whitelist of existing view
* -cw, --clearwhitelist: (optional) clear out the existing whitelist and add specified entries (using -w)
* -x, --updateexistingview: (optional) allow the script to update an existing view (otherwise quit if view exists)
* -show, --show: (optional) display existing view settings and exit

## Datalock Parameters

* -lm, --lockmode: (optional) Compliance, Enterprise or None (default is None)
* -al, --autolockminutes: (optional) number of idle minutes before auto locking (default is 0 which means no autolocking)
* -ml, --minimumlockminutes: (optional) minimum number of minutes when manual locking (default is 0)
* -lu, --lockunit: (optional) period selection for defaul and maximum lock periods, minutes, hours, days (default is minutes)
* -dl, --defaultlockperiod: (optional) default manual lock duration, default is 1 (see lockunit above)
* -xl, --maximumlockperiod: (optional) maximum manual lock duration, default is 1 (see lockunit above)
* -lt, --manuallockmode': (optional) ReadOnly or FutureATime (default is ReadOnly
