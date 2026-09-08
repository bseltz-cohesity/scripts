# Recover MS SQL Databases Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script recovers one or more Microsoft SQL Server databases from Cohesity backups (using the v2 recovery API), with support for point-in-time log replay, renaming, alternate instance/server recovery, flat-file recovery, and bulk recovery of an entire SQL server.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/python/restoreSQLv2/restoreSQLv2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreSQLv2.py
# end download commands
```

## Components

* restoreSQLv2.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so.

By default the script runs in test mode and only reports what it would do. Add `-cm`/`--commit` to actually perform the recoveries.

To restore a single database in place (overwriting the original):

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -ow \
                   -cm
```

To restore a database to a new name on the same server:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -td ProdDB_Restored \
                   -cm
```

To restore a database to a different server/instance:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -ts sql2.mydomain.net \
                   -ti MSSQLSERVER \
                   -mdf 'D:\SQLData' \
                   -ldf 'D:\SQLLogs' \
                   -cm
```

To restore with a point-in-time log replay and wait for completion with progress:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -ow \
                   -lt '2019-09-29 17:51:01' \
                   -w -pr \
                   -cm
```

To restore every database on a server (excluding system DBs), prefixing the recovered names:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -adb \
                   -pre restored \
                   -mdf 'D:\SQLData' \
                   -ldf 'D:\SQLLogs' \
                   -cm
```

To restore a list of databases from a text file (one name per line):

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sdl dbnames.txt \
                   -ow \
                   -cm
```

To recover database files only (no attach) to a flat file location:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -ffp 'D:\Restore' \
                   -cm
```

To export the current data/log file paths for a server (for later reuse with -importpaths):

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -ep
```

To preview the source data/log file paths for a database without performing a recovery:

```bash
./restoreSQLv2.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -sp
```

To connect through Helios or MCM:

```bash
./restoreSQLv2.py -v helios.cohesity.com \
                   -u myuser \
                   -d mydomain.net \
                   -c myclustername \
                   -ss sql1.mydomain.net \
                   -sd ProdDB \
                   -ow \
                   -cm
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) org to impersonate
* -i, --useapikey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (required when -v is helios.cohesity.com or -mcm is used)
* -m, --mfacode: (optional) MFA code for authentication

## DB Selection Parameters

* -ss, --sourceserver: (required) protection source where the DB(s) were backed up
* -sd, --sourcedb: (optional, repeatable) name of a source DB to restore (accepts instance/dbname format; comma-separated lists also accepted)
* -sdl, --sourcedblist: (optional) path to a text file containing one source DB name per line
* -adb, --alldbs: (optional) restore all databases found on -sourceserver
* -isdb, --includesystemdbs: (optional) when using -alldbs, include Master, Model and MSDB
* -si, --sourceinstance: (optional) restrict selection to a specific source SQL instance
* -sn, --sourcenodes: (optional, repeatable) restrict selection to DBs backed up from specific AAG nodes

Only one of -alldbs, -sourcedblist or -sourcedb may be used at a time.

## Target/Rename Parameters

* -ts, --targetserver: (optional) server to recover the DB(s) to (defaults to sourceserver)
* -ti, --targetinstance: (optional) SQL instance name on the target server (defaults to MSSQLSERVER when recovering to an alternate server/instance)
* -td, --targetdb: (optional) new name for the recovered DB (only valid when restoring a single DB; defaults to the original name)
* -pre, --prefix: (optional) prefix to add to the recovered DB name
* -suf, --suffix: (optional) suffix to add to the recovered DB name

## File Location Parameters

* -mdf, --mdffolder: (optional) target folder for the primary data file (.mdf); required when renaming or recovering to an alternate server/instance unless source paths can be discovered automatically
* -ldf, --ldffolder: (optional) target folder for the log file (.ldf) (defaults to -mdffolder)
* -ffp, --flatfilepath: (optional) recover database files only (no attach) to this folder
* -ndf, --ndffolder: (optional, repeatable) secondary data file mapping, as filenamePattern=directory (e.g. `-ndf 'ProdDB_2.ndf=D:\SQLData2'`)
* -ep, --exportpaths: (optional) export the current data/log file paths for -sourceserver to a JSON file for later reuse
* -ip, --importpaths: (optional) import previously exported file paths instead of querying the source server
* -sp, --showpaths: (optional) display the source data/log file paths without performing a recovery

## Point-in-Time / Log Replay Parameters

* -lt, --logtime: (optional) point in time to recover to, e.g. '2019-09-29 17:51:01' (defaults to now)
* -lrd, --lograngedays: (optional) number of days back to search for a usable log range (default is 14)
* -nl, --nologs: (optional) skip log replay and restore to the base snapshot only
* -nt, --newerthan: (optional) only consider backups newer than this many days old

## Recovery Behavior Parameters

* -ow, --overwrite: (optional) overwrite the original database (required when restoring in place without renaming)
* -nr, --norecovery: (optional) leave the database in a restoring/no-recovery state
* -kc, --keepcdc: (optional) preserve Change Data Capture settings
* -ctl, --capturetaillogs: (optional) capture the tail-end log backup before recovery
* -ia, --includearchives: (optional) allow recovery from archive (non-local) snapshots

## Execution Parameters

* -cm, --commit: (optional) actually perform the recoveries (default is test/preview mode)
* -w, --wait: (optional) wait for the recoveries to complete
* -pr, --progress: (optional) show per-database progress while waiting (implies -wait)
* -ps, --pagesize: (optional) page size used when searching for all DBs on a server (default is 100)
* -dpr, --dbsperrecovery: (optional) maximum number of databases per recovery task (default is 100)
* -st, --sleeptime: (optional) seconds to wait between status checks while waiting (minimum/default is 20/60)
* -dbg, --dbg: (optional) write debug JSON (search results, recovery params) and enable the API debugger log
