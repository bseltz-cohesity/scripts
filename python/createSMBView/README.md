# Create an SMB View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a new SMB View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createSMBView/createSMBView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x createSMBView.py
```

## Components

* [createSMBView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createSMBView/createSMBView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

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
                   -a '192.168.1.10, myserver' \
                   -a 192.168.1.11
#end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --viewname: name of new view to create
* -r, --readonly: (optional) principal to grant readonly access (can be used multiple times)
* -w, --readwrite: (optional) principal to grant read/write access (can be used multiple times)
* -f, --fullcontrol: (optional) principal to grant full control (can be used multiple times)
* -q, --qospolicy: (optional) defaults to 'Backup Target Low' or choose 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low'
* -s, --storageDomain: (optional) name of storage domain to place view data (defaults to DefaultStorageDomain)
* -a, --allowlist: (optional) ip (and optional description) address to whitelist (can be used multiple times)
