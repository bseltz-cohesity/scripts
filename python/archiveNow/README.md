# Archive latest Snapshot Now using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives the latest local snapshot from the specified jobs.

## Components

* [archiveNow.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveNow/archiveNow.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveNow/archiveNow.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x archiveNow.py

```

Place both files in a folder together and run the main script like so:

```bash
./archiveNow.py -v mycluster -u myuser -d mydomain.net -j myjob -t mytarget -k 90 -c
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: (optional) name of protection job (repeat for multiple)
* -l, --joblist: (optional) text file of job names (one per line)
* -xj, --excludejobname: (optional) name of protection job (repeat for multiple)
* -xl, --excludejoblist: (optional) text file of job names (one per line)
* -k, --keepfor: keepfor X days
* -t, --target: name of the external target
* -f, --fromtoday: (optional) calculate -k from today instead of from snapshot date
* -c, --commit: (optional) if omitted, will just report what would happen
* -a, --archiveonfailure: (optional) archive failed jobs

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
