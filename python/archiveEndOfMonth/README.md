# Archive an End Of Month Snapshot using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives an existing local snapshot taken on the last day of the month.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/archiveEndOfMonth/archiveEndOfMonth.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/archiveEndOfMonth/pyhesity.py
chmod +x archiveEndOfMonth.py
# end download commands
```

## Components

* archiveEndOfMonth.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./archiveEndOfMonth.py -v mycluster -u myuser -d mydomain.net -j myjob1 -j myjob2 -k 365 -t S3
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job (repeat the -j parameter for multiple jobs)
* -k, --keepfor: keepfor X days
* -t, --targetname: name of the external target to archive to

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
