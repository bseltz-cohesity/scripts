# Restore a Files from Cohesity backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores files from a Cohesity physical server backup.

## Components

* restoreFiles.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/restoreFiles/restoreFiles.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/restoreFiles/pyhesity.py
chmod +x restoreFiles.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restoreFiles.py -v mycluster \
                  -u myusername \
                  -d mydomain .net \
                  -s server1.mydomain.net \
                  -t server2.mydomain.net \
                  -n /home/myusername/file1 \
                  -n /home/myusername/file2 \
                  -p /tmp/restoretest/ \
                  -f '2020-04-18 18:00:00' \
                  -w
# end example
```

```text
Connected!
Restoring Files...
Restore finished with status kSuccess
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --sourceserver: name of source server
* -t, --targetserver: (optional) name of target server (defaults to source server)
* -n, --filename: (optional) path of file to recover (repeat parameter for multiple files)
* -l, --filelist: (optional) text file containing multiple files to restore
* -p, --restorepath: (optional) path to restore files on target server (defaults to original location)
* -f, --filedate: (optional) select backup version at or after specified date (defaults to latest backup)
* -w, --wait: (optional) wait for completion and report status

## file names and paths

File names must be specified as absolute paths like:

Linux: /home/myusername/file1
Windows: /C/Users/MyUserName/Documents/File1

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
