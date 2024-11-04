# Change Local Snapshot Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script changes the retention of snapshots on the locak cluster.

## Components

* [changeLocalRetention.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/changeLocalRetention/changeLocalRetention.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/changeLocalRetention/changeLocalRetention.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x changeLocalRetention.py
# end download commands
```

First, perform a test run. To extend the retention of snapshots to 14 days (after the original backup date):

```bash
./changeLocalRetention.py -v mycluster -u myuser -k 14
```

If you're happy with the output you can commit the change by adding -x (--commit)

```bash
./changeLocalRetention.py -v mycluster -u myuser -k 14 -x
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -k, --keepfor: number of days (from original backup date) to retain the snapshots
* -t, --backupType: (optional) kLog, kRegular, kFull, kSystem (default is AllExceptLogs)
* -log, --includelogs: (optional) update retention for log backups (will skip logs by default)
* -a, --allowreduction: (optional) allow retention to be reduced
* -x, --commit: (optional) perform updates (otherwise just show what would happen)
* -n, --newerthan: (optional) only process snapshots newer than X days
* -o, --olderthan: (optional) only process snapshots olderthan than X days
* -g, --greaterthan: (optional) only process snapshots with existing retentions longer than X days
* -j, --jobname: (optional) one or more protection job names to include (default is all jobs)
* -l, --joblist: (optional) text file of job names to include (default is all jobs)
* -id, --runid: (optional) run ID to operate on
* -dt, --rundate: (optional) run date to operate on (e.g. '2024-01-03 23:30')
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
