# Restart Canceled or Failed Archive Tasks using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restarts canceled or failed archive tasks.

## Components

* [restartArchives.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restartArchives/restartArchives.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restartArchives/restartArchives.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restartArchives.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./restartArchives.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -k 90 -x 5 -t MyVault -n 365
```

```text
Connected!
searching for cencelled archive tasks...
2019-05-19 23:20:00  My Job  (would archive for 10 days)
2019-05-18 23:20:01  My Job  (would archive for 9 days)
2019-05-18 05:08:13  My Job  (would archive for 7 days)
2019-05-17 23:20:00  My Job  (expiring in 5 days. skipping...)
2019-05-17 09:48:07  My Job  (expiring in 2 days. skipping...)
```

If you are happy with what would occur, re-run the command using the -a switch to actually start the archive tasks.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job
* -k, --keepfor: keepfor X days
* -t, --target: name of the external target
* -x, --ifexpiringafter: (optional) skip if snapshot is expiring in x days
* -a, --archive: (optional) start the archives, otherwise just report what would happen

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
