# Generate Estimated Storage Per Object Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/python/storagePerObjectReport/storagePerObjectReport.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x storagePerObjectReport.py
# end download commands
```

## Components

* storagePerObjectReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./storagePerObjectReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

## Parameters

## Authentication Parameters

* -v, --vip: (optional) one or more names or IPa of Cohesity clustera to connect to (repeat for multiple) default is helios.cohesity.com
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) one or more helios/mcm clusters to connect to (repeat for multiple)
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -y, --growthdays: (optional) show growth over the last X days (default is 7)
* -of: --outfolder: (optional) where to write report html (default is current directory)
* -x, --unit: (optional) KiB, MiB, GiB, or TiB] (default is GiB)
* -n, --numruns: (optional) number of runs per API query (default is 500)
* -s, --skipdeleted: (optional) skip deleted protection groups
* -debug, --debug: (optional) print verbose output

## Column Descriptions

* Job Name: name of protection group
* Tenant: name of organization
* Environment: protection group type
* Source Name: name of registered source (e.g. vCenter, server, etc.)
* Object Name: name of object (e.g. VM, NAS share, database, etc.)
* Logical GiB: front-end size of object as reported by the source
* GiB Written: amount of deduped/compressed data, for this object, resident on Cohesity (before adding resiliency striping overhead)
* GiB Written plus Resiliency: amount of deduped/compressed data, for this object, resident on Cohesity (after adding resiliency striping overhead)
* Job Reduction Ratio: dedup/compression ratio of protection group
* GiB Written Last 7 Days: amount of deduped/compressed data added, for this object, in past X days
* GiB Archived: amount of deduped/compressed data, for this object, resident on cloud archive targets
* GiB per Archive Target: amount of deduped/compressed data, for this object, resident on each archive target
