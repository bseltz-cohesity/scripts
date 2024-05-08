# Generate Estimated Storage Per Object Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/storagePerObjectReport/storagePerObjectReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
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

To report on multiple clusters:

```bash
# example
./storagePerObjectReport.py -v mycluster1 -v mycluster2 -u myusername -d mydomain.net
# end example
```

To connect through Helios:

```bash
# example
./storagePerObjectReport.py -u myuser@mydomain.net -c mycluster1 -c mycluster2
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

Index | Name | Description
--- | --- | ---
A | Cluster Name | name of cluster queried
B | Origin | local or replica
C | Stats Age | age (days) of stats (should be 2 or less)
D | Protection Group | name of protection group
E | Tenant | name of organization
F | Storage Domain ID | ID of storage domain
G | Storage Domain Name | name of storage domain
H | Environment | protection group type
I | Source Name | name of registered source (e.g. vCenter, server, etc.)
J | Object Name | name of object (e.g. VM, NAS share, database, etc.)
K | Front End Allocated | front-end allocated size of object as reported by the source
L | Front End Used | front-end used size of object as reported by the source
M | Stored (Before Reduction) | amount of data stored for this object, before dedup/compression
N | Stored (After Reduction) | amount of data stored for this object, after dedup/compression
O | Stored (After Reduction and Resiliency) | amount of data stored for this object, after dedup/compression and resiliency
P | Reduction Ratio | dedup/compression ratio of protection group
Q | Raw Change Last X Days | change of Raw consumption for this object, in past X days
R | Snapshots | number of local backups resident on Cohesity
S | Log Backups | number of log backups (if applicable) resident on Cohesity
T | Oldest Backup | oldest backup resident on Cohesity
U | Newest Backup | newest backup resident on Cohesity
V | Newest Datalock Expiry | datalock expiration date of most recent backup
W | Archive Count | number of archives stored in external targets
X | Oldest Archive | oldest archive available for restore
Y | GiB Archived | amount of deduped/compressed data, for this object, resident on cloud archive targets
Z | GiB per Archive Target | amount of deduped/compressed data, for this object, resident on each archive target
AA | Description | description of protection group or view
AB | VMWare Tags | VMWare Tags assigned to VM
