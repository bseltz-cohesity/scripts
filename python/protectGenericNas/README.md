# Protect Generic NAS Mountpoints using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects generic NAS volumes.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectGenericNas/protectGenericNas.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectGenericNas.py
# end download commands
```

## Components

* [protectGenericNas.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectGenericNas/protectGenericNas.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectGenericNas.ps1 -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -p 'My Policy' \
                        -j 'My New Job' \
                        -m '\\myserver\myshare'
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -mfa, --mfacode: (optional) MFA code for authentication
* -em, --emailmfacode: (optional) send MFA code via email

## Selection Parameters

* -j, --jobname: name of the job to make changes to (repeat paramter for multiple jobs)
* -i, --include: (optional) include path (default is /) repeat for multiple
* -n, --includelist: (optional) text file with include paths (one per line)
* -e, --exclude: (optional) exclude path (repeat for multiple)
* -x, --excludelist: (optional) text file with exclude paths (one per line)
* -m, --mountpath: (optional) generic NAS mount path to protect (repeat for multiple)
* -f, --mountpathlist: (optional) text file with NAS mount paths to protect (one per line)

## New Job Parameters

* -p, --policyname: (optional) name of protection policy (only required for new job)
* -s, --starttime: (optional) start time for new job (default is '20:00')
* -tz, --timezone: (optional) default is 'America/Los_Angeles'
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -ei, --enableindexing: (optional) enable indexing
* -sd, --storagedomain: (optional) default is 'DefaultStorageDomain'
* -z, --paused: (optional) pause future runs
