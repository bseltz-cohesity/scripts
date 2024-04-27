# Delete Local Server Backups with  Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script searches for a VM or physical server, and deletes all local snapshots of that VM or server.

If you run the script without the --delete switch, the script will only display what it would delete. Use the --delete switch to actually perform the deletions.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deleteServerBackups/deleteServerBackups.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x deleteServerBackups.py
# end download commands
```

## Components

* [deleteServerBackups.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deleteServerBackups/deleteServerBackups.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./deleteServerBackups.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -s myserver.mydomain.net \
                  -l serverlist.txt \
                  -o 7 \
                  -x
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --servername: (optional) name of server to delete (use multiple times for multiple)
* -l, --serverlist: (optional) list of server names in a text file
* -j, --jobname: filter by job name
* -o, --olderthan: delete backups older than X days (defaults to 0)
* -x, --delete: perform deletions (test run by default)
