# Add Isilon Volumes to a Protection Job Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds Isilon Volumes to a protection job.

Note: this script is written for Cohesity 6.5.1 and later

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectIsilon/protectIsilon.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectIsilon.py
# end download commands
```

## Components

* [protectIsilon.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectIsilon/protectIsilon.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectIsilon.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -j 'My Backup Job' \
                   -s myisilon
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
* -m, --mfacode: (optional) MFA code for authentication
* -em --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of the job to add the server to
* -s, --sourcename: name of registered Isilon to protect
* -z, --zonename: (optional) protect specific zones (repeat for multiple zones)
* -n, --volumename: (optional) protect specific volumes(repeat for multiple volumes)
* -l, --volumelist: (optional) list of volume names in a text file
* -ev, --excludevolumename: (optional) name of volume to exclude (repeat for multiple)
* -el, --excludevolumelist: (optional) text file of volume names to exclude (one per line)
* -ifs, --includerootifs: (optional) /ifs is skipped by default
* -i, --include: (optional) file path to include (use multiple times for multiple paths)
* -n, --includefile: (optional) a text file full of include paths
* -x, --exclude: (optional) file path to exclude (use multiple times for multiple paths)
* -f, --excludefile: (optional) a text file full of exclude file paths
* -cl, --usechangelist: (optional) use Isilon change list for incremental backups (default is false)

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -ei, --enableindexing: (optional) default is no indexing
* -cad, --cloudarchivedirect: (optional) use direct cloud archiving
* -ip, --incrementalsnapshotprefix: (optional) prefix of Netapp snapshot name
* -fp, --fullsnapshotprefix: (optional) prefix of Netapp snapshot name
* -enc, --encryptionenabled: (optional) enable in-flight encryption of data between the Isilon and Cohesity
