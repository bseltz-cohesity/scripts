# Expire Old Snapshots using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script will expire old local snapshots. Optionally you can confirm replication before expiring the local snapshot.

## Warning! This script will deleted data from the Cohesity cluster! Make sure you know what you are doing

## Components

* [expireOldSnapshots.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireOldSnapshots/expireOldSnapshots.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireOldSnapshots/expireOldSnapshots.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x expireOldSnapshots.py
# end download commands
```

First, run the script without the -e parameter to see what would be expired

```bash
# test run only, no -e parameter, seach for snapshots older than 30 days
./expireOldSnapshots.py -v mycluster -u myuser -d mydomain.net -k 30
# end
```

When you're happy about what would be deleted you can include the -e switch to cause these snapshots to be expired

```bash
# expire snapshots older than 30 days (ignore replication status)
./expireOldSnapshots.py -v mycluster -u myuser -d mydomain.net -k 30 -e
# end
```

or if you want to ensure that the snapshots have been successfully replicated before exiring, use the -r switch in conjunction with the -e switch

```bash
# expire snapshots older than 30 days (only if successfully replicated)
./expireOldSnapshots.py -v mycluster -u myuser -d mydomain.net -k 30 -e -r
# end
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key (will prompt or use stored password if omitted)
* -j, --jobname: (optional) name of job to focus on (repeat for multiple jobs)
* -l, --joblist: (optional) text file of job names to focus on (one per line)
* -k, --daystokeep: number of days to keep local snapshots
* -e, --expire: (optional) expire snapshots older than k days
* -r, --confirmreplication: (optional) do not expire if not replicated
* -rt, --replicationtarget: (optional) specific cluster name to use for confirmreplication
* -a, --confirmarchive: (optional) do not expire local snapshot if not archived
* -at, --arcvhivetarget: (optional) specific target name to use for confirmarchive
* -n, --numruns: (optional) number of runs to retrieve at a time (default is 1000)
* -s, --skipmonthlies: (optional) don't expire snapshots from the first day of the month
* -ac, --activeconfirmation: (optional) active replication confirmation
* -ao, --activeonly: (optional) skip confirmations for inactive jobs

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
