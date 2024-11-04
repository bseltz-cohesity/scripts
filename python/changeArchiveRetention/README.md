# Change Archive Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script changes the retention of archived snapshots.

## Components

* [changeArchiveRetention.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/changeArchiveRetention/changeArchiveRetention.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/changeArchiveRetention/changeArchiveRetention.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x changeArchiveRetention.py
# end download commands
```

First, perform a test run. To extend the retention of archives to 14 days (after the original backup date):

```bash
./changeArchiveRetention.py -v mycluster -u myuser -k 14
```

If you're happy with the output you can commit the change by adding -x (--commit)

```bash
./changeArchiveRetention.py -v mycluster -u myuser -k 14 -x
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

* -k, --keepfor: number of days (from original backup date) to retain the archives
* -b, --backupType: (optional) kLog, kRegular, kFull, kSystem or kAll (default is kAll)
* -log, --includelogs: (optional) update retention for log backups (will skip logs by default)
* -a, --allowreduction: (optional) allow retention to be reduced
* -x, --commit: (optional) perform updates (otherwise just show what would happen)
* -n, --newerthan: (optional) only process archives newer than X days
* -o, --olderthan: (optional) only process archives olderthan than X days
* -g, --greaterthan: (optional) only process archives with existing retentions longer than X days
* -j, --jobname: (optional) one or more protection job names to include (default is all jobs)
* -l, --joblist: (optional) text file of job names to include (default is all jobs)
* -n, --numruns: (optional) runs per api querty (default is 1000)

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```
