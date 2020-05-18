# Restore a Folder from Cohesity backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores a folder from a Cohesity physical server backup.

## Components

* restoreFolder.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/restoreFolder/restoreFolder.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/restoreFolder/pyhesity.py
chmod +x restoreFolder.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restoreFolder.py -v mycluster -u myuser -d mydomain.net -j myjobname -s server1.mydomain.net -f /home/myuser -t server2.mydomain.net -p /tmp/restore
# end example
```

```text
Connected!
Restoring server1.mydomain.net:/home/myuser to server2.mydomain.net:/tmp/restore
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: (optional) username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API keey for authentication
* -j, --jobName: Name of protection job
* -s, --sourceServer: Name of source server
* -f, --sourceFolder: Path of the folder to be recovered
* -t, --targetServer: (optional) Name of target server
* -p, --targetPath: (optional) Destination path

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
