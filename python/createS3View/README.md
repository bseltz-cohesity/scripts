# Create an S3 View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a new S3 View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createS3View/createS3View.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x createS3View.py
```

## Components

* [createS3View.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createS3View/createS3View.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./createS3View.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -n newview1 \
                  -q 'TestAndDev High' \
                  -s mystoragedomain \
                  -a '192.168.1.10, myserver' \
                  -a 192.168.1.11
#end example
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --viewname: name of new view to create
* -q, --qospolicy: (optional) defaults to 'Backup Target Low' or choose 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low' (defailt is TestAndDev High)
* -s, --storageDomain: (optional) name of storage domain to place view data (defaults to DefaultStorageDomain)
* -a, --allowlist: (optional) ip (and optional description) address to whitelist (can be used multiple times)
