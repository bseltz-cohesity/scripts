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
                        -t 'America/New_York' \
                        -ei \
                        -m '\\myserver\myshare' \
                        -c
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: name of the job to make changes to (repeat paramter for multiple jobs)
* -p, --policyname: (optional) name of protection policy (only required for new job)
* -s, --starttime: (optional) start time for new job (default is '20:00')
* -i, --include: (optional) include path (default is /) repeat for multiple
* -n, --includefile: (optional) text file with include paths (one per line)
* -e, --exclude: (optional) exclude path (repeat for multiple)
* -x, --excludefile: (optional) text file with exclude paths (one per line)
* -t, --timezone: (optional) default is 'America/Los_Angeles'
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -ei, --enableindexing: (optional) enable indexing
* -m, --mountpath: (optional) generic NAS mount path to protect (repeat for multiple)
* -f, --mountpathfile: (optional) text file with NAS mount paths to protect (one per line)
* -c, --cloudarchivedirect: (optional) create cloud archive direct job
* -sd, --storagedomain: (optional) default is 'DefaultStorageDomain'
