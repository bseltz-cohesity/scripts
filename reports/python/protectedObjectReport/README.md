# Report Protected Objects using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script generates a report of protected objects. Output is written to a CSV file.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/protectedObjectReport/protectedObjectReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectedObjectReport.py
```

## Components

* protectedObjectReport.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./protectedObjectReport.py -v mycluster \
                           -u myusername \
                           -d mydomain.net
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
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -o, --objectname: (optional) individual object name(s) to include (repeat for multiple objects)
* -l, --objectlist: (optional) text file of object names to include (one per line)
