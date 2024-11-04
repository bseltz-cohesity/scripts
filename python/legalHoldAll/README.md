# Add or Remove Legal Hold using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script add or remote legal hold from all backups on the cluster.

## Components

* [legalHoldAll.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHoldAll/legalHoldAll.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/legalHoldAll/legalHoldAll.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x legalHoldAll.py
# end download commands
```

To add legal hold to all backups:

```bash
./legalHoldAll.py -v mycluster -u myuser -a
```

To remove legal hold from all backups::

```bash
./legalHoldAll.py -v mycluster -u myuser -r
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

## Other Parameters

* -j, --jobname: (optional) one or more protection job names to include
* -l, --joblist: (optional) text file of job names to include
* -n, --numruns: (optional) runs per api querty (default is 1000)
* -a, --addhold: (optional) add legal holds
* -r, --removehold: (optional) remove legal holds
* -t, --showtrue: (optional) show runs where legal hold is present
* -f, --showfalse: (optional) show runs where legal hold is not present
* -p, --pushtoreplicas: (optional) push legal hold adds/removes to replicas

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
