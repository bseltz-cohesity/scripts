# Expire Outdated Replicas using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

When backups run, on the local cluster, their retention date is set to X days from the backup start time. If the backup is replicated to a remote cluster, the retention on the remote cluster is set to X days from the replication completion time. So if backup/replication took significant time, the expiration time of the replica could be significantly later than the expiration of the local copy. This is rarely a concern, but in cases where regulatory/policy reqirements demand prompt expiration of the backups, we can expire these "outdated" replicas.

This script will search all existing replicas and expire any that are past the adjusted retention period (local backup start time + X days).

## Warning! This script will deleted data from the Cohesity cluster! Make sure you know what you are doing

## Components

* [expireOutdatedReplicas.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireOutdatedReplicas/expireOutdatedReplicas.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireOutdatedReplicas/expireOutdatedReplicas.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x expireOutdatedReplicas.py
# end download commands
```

First, run the script without the -x parameter to see what would be expired

```bash
./expireOutdatedReplicas.py -v mycluster -u myuser -d mydomain.net -y 14
```

When you're happy about what would be expired you can include the -x switch to cause these replicas to be expired

```bash
./expireOutdatedReplicas.py -v mycluster -u myuser -d mydomain.net -y 14 -x
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of job to focus on (repeat for multiple jobs)
* -l, --joblist: (optional) text file of job names to focus on (one per line)
* -y, --daysback: (optional) number of days back to look (default is 7 days)
* -x, --expire: (optional) expire replicas
* -n, --numruns: (optional) number of runs to retrieve at a time (default is 1000)

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
