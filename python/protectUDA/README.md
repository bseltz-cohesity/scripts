# Protect a Universal Data Adapter Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a protection group for a Universal Data Adapter source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectUDA/protectUDA.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectUDA.py
# end download commands
```

## Components

* [protectUDA.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectUDA/protectUDA.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectUDA.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -j 'my uda backup' \
                -n myuda1.mydomain.net \
                -p 'my policy'
```

## Basic Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -s, --sourcename: IP or FQDN of protection source to register
* -j, --jobname: Name of protection group to create
* -p, --policyname: Name of protection policy to use

## UDA Parameters

* -cc, --concurrency: (optional) number of concurrent backup streams (default is 1)
* -m , --mounts: (optional) number of mounts (default is 1)
* -fa, ---fullbackupargs: (optional) default is ""
* -ia, --incrbackupargs: (optional) default is ""
* -la, --logbackupargs: (optional) default is ""
* -n, --objectname: (optional) database names to define (repeat for multiple)

## Optional Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --pause: (optional) pause future runs of new job
* -q, --qospolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -al, --alerton: (optional) None, kFailure, kSuccess or kSlaViolation (repeat for multiple)
* -ar, --recipient: (optional) email address to send alerts to (repeat for multiple)
