# Restore a DB2 Backup Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores a DB2 backup. DB2 protection/recovery on this cluster is implemented through the Universal Data Adapter (UDA) framework using DB2-specific scripts, so this script builds a `kUDA` recovery request under the hood, passing DB2-specific behavior (redirected restore paths, rollforward, timeouts, etc.) to the underlying DB2 scripts as named `recoveryJobArguments`.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreDB2/restoreDB2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreDB2.py
# end download commands
```

## Components

* [restoreDB2.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreDB2/restoreDB2.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./restoreDB2.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -s DB2SOURCE \
                -n SAMPLE \
                -l \
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
* -t, --tenant: (optional) tenant to impersonate
* -np, --noprompt: (optional) don't prompt for credentials if none are found/stored
* -m, --mfacode: (optional) MFA code
* -e, --emailmfacode: (optional) request an emailed MFA code
* -s, --sourceserver: fully qualified name of the DB2 source/database as registered on the cluster
* -a, --recoveryargs: (optional) repeat for multiple additional recoveryJobArguments not covered by the flags below, e.g. 'my_custom_key=my_custom_value'

## Additional Parameters

* -ts, --targetserver: (optional) registered DB2 target host to restore to (defaults to same as sourceserver)
* -n, --objectname: (optional) name of database to restore (repeat for multiple)
* -p, --prefix: (optional) apply prefix to restored database (only valid when using -n, --objectname)
* -lt, --logtime: (optional) point in time to replay the logs to during the restore (e.g. '2026-08-10 09:00:00')
* -l, --latest: (optional) replay the logs to the latest log backup date
* -w, --wait: (optional) wait for the restore to complete and report end status (e.g. kSuccess)
* -o, --overwrite: (optional) overwrite warning when writing to original location
* -cc, --concurrency: (optional) number of concurrency streams (default is 1)
* -mnt, --mounts: (optional) number of mounts (default is 1)

## Restore Settings (Redirected Restore)

* -rd, --redirected: (optional) perform a redirected restore instead of a regular restore
* -rs, --redirectionscript: (optional) redirection script path
* -ndp, --newdatapath: (optional) new data path
* -nlp, --newlogpath: (optional) new log path
* -ldd, --localdbdir: (optional) local database directory
* -nrf, --norollforward: (optional) disable rollforward database (enabled by default)

## Advanced Options

* -po, --parallelobjects: (optional) number of objects to restore in parallel
* -rt, --rpctimeout: (optional) RPC timeout, in seconds
* -mio, --maxiobytes: (optional) max IO read size from Cohesity, in bytes
* -ev, --envvars: (optional) environment variables to pass to the restore job

## Point in Time Recovery

By default (if both **--latest** and **--logtime** are omitted), the latest full/incremental snapshot time will be used for the restore.

If you want to replay the logs to the very latest available point in time, use the **--latest** parameter, or if you want to replay logs to a specific point in time, use the **--logtime** parameter and specify a date and time in military format like so:

```bash
--logtime '2026-08-10 09:00:00'
```

Note that when the --logtime parameter is used with databases where no log backups exist, the full/incremental backup that occurred at or before the specified log time will be used. Also note that if a logtime is specified that is newer than the latest log backup, the latest log backup time will be used.

If a full snapshot exists that is newer than both the currently selected snapshot and the best point in time reachable via logs, the script automatically switches to that newer full snapshot instead of rolling forward through a now-stale log chain, since a fresh full backup supersedes the log backups that came before it.

## Examples

Restore to the original location, overwriting the existing database:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -o
```

Restore to the latest available point in time (logs or a newer full snapshot) and wait for completion:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -l -w
```

Restore to a specific point in time:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -lt '2026-08-10 09:00:00' -w
```

Restore to a different registered DB2 host:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -ts DB2TARGET -n SAMPLE -w
```

Restore and rename the database using a prefix instead of overwriting in place:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -p RESTORED -w
```

Redirected restore with new data/log paths and a local database directory:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE \
                -rd -ndp /db2/newdata -nlp /db2/newlogs -ldd /db2/local \
                -w
```

Redirected restore without rolling the database forward after recovery:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -rd -ndp /db2/newdata -nlp /db2/newlogs -nrf -w
```

Restore with advanced tuning options (parallel objects, RPC timeout, max IO size, environment variables):

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE \
                -po 4 -rt 120 -mio 4194304 -ev 'DB2INSTANCE=db2inst1' \
                -w
```

Restore multiple objects in a single run, each renamed with a prefix:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE1 -n SAMPLE2 -n SAMPLE3 -p RESTORED -w
```

Restore through Helios, selecting the managed cluster by name:

```bash
./restoreDB2.py -v helios.cohesity.com -u myusername -i -pwd myapikey \
                -c mycluster -s DB2SOURCE -n SAMPLE -l -w
```

Restore using a custom recoveryJobArguments key not covered by the built-in flags:

```bash
./restoreDB2.py -v mycluster -u myusername -d mydomain.net \
                -s DB2SOURCE -n SAMPLE -a 'my_custom_key=my_custom_value' -w
```
