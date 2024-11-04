# Clone Oracle Backups to a View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script clones Oracle backups to a user-accessible Cohesity View

## Components

* [cloneOracleBackupsToView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/cloneOracleBackupsToView/cloneOracleBackupsToView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/cloneOracleBackupsToView/cloneOracleBackupsToView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cloneOracleBackupsToView.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./cloneOracleBackupsToView.py -v mycluster \
                              -u myuser \
                              -d mydomain.net \
                              -j myoraclejob \
                              -o oracle1.mydomain.net \
                              -n myview
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -j, --jobname: name of protection job
* -o, --objectname: name of oracle server
* -n, --viewname: name of view to use or create
* -q, --qospolicy: (optional) 'Backup Target Low', 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low' (default is 'TestAndDev High')
* -w, --whitelist: (optional) e.g. '192.168.1.0,255.255.255.0' or '192.168.2.23' (repeat for multiple entries)
* -x, --deleteview: (optional) delete existing view and exit

## Note

The Protection Job and the View must be in the same Storage Domain.
