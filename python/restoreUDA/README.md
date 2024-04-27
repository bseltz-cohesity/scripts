# Restore a Univeral Data Adapter Backup Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores a UDA backup.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreUDA/restoreUDA.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreUDA.py
# end download commands
```

## Components

* [restoreUDA.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreUDA/restoreUDA.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./restoreUDA.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -s myuda1.mydomain.net \
                -t myuda2.mydomain.net \
                -a 'target-dir=/var/lib/pgsql/10/data/' \
                -w
```

## Basic Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) cluster to connect to when connecting through Helios or MCM
* -s, --sourceserver: IP or FQDN of protection source to register
* -a, --recoveryargs: (optional) repeat for multiple arguments, e.g. 'target-dir=/var/lib/pgsql/10/data/'

## Additional Parameters

* -t, --targetserver: (optional) Server name to restore to (defaults to same as sourceserver)
* -n, --objectname: (optional) name of database to restore (repeat for multiple)
* -p, --prefix: (optional) apply prefix to restored database (only vaid when using -n, --objectname)
* -lt, --logtime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -l, --latesst: (optional) Replay the logs to the latest log backup date
* -w, --wait: (optional) Wait for the restore to complete and report end status (e.g. kSuccess)
* -o, --overwrite: (optional) Overwrite warning when writing to original location
* -cc, --concurreny: (optional) number of concurrency streams (default is 1)
* -m, --mounts: (optional) number of mounts (default is 1)

## Point in Time Recovery

By default (if both **--latest** and **--logtime** are omitted), the latest full/incremental snapshot time will be used for the restore.

If you want to replay the logs to the very latest available point in time, use the **--latest** parameter, or if you want to replay logs to a specific point in time, use the **--logtime** parameter and specify a date and time in military format like so:

```bash
--logtime '2019-01-20 23:47:02'
```

Note that when the --logtime parameter is used with databases where no log backups exist, the full/incremental backup that occurred at or before the specified log time will be used. Also note that if a logtime is specified that is newer than the latest log backup, the latest log backup time will be used.
