# Add Subnet Whitelist Entries to Cohesity Views Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script adds subnet whitelist entries (NFS/SMB/S3 access) to one or more existing Cohesity views.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewAddWhitelistEntries/viewAddWhitelistEntries.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x viewAddWhitelistEntries.py
```

## Components

* [viewAddWhitelistEntries.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewAddWhitelistEntries/viewAddWhitelistEntries.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./viewAddWhitelistEntries.py -v mycluster \
                             -u myusername \
                             -d mydomain.net \
                             -n view1 -n view2 \
                             -i 192.168.1.0/24 \
                             -i 192.168.2.11
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

* -n, --viewname: name of view to modify (can be specified multiple times or as a comma separated list)
* -vl, --viewlist: (optional) text file of view names to modify (one per line)
* -i, --ip: cidr (e.g. 192.168.1.0/24) to add to the whitelist (can be specified multiple times or as a comma separated list; /32 assumed if no prefix given)
* -il, --iplist: (optional) text file of cidrs to add (one per line)
* -rs, --rootsquash: (optional) whitelist entries use root squash
* -as, --allsquash: (optional) whitelist entries use all squash
* -ro, --readonly: (optional) grant only read access (default is read/write)

## Notes

* At least one view (-n or -vl) and one IP/cidr (-i or -il) are required.
* Adding a cidr replaces any existing whitelist entry for the same IP on that view.
* Views that are not found are skipped with a warning; other requested views are still processed.
