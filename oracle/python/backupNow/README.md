# Backup Now Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to fimish and report the end status of the job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/backupNow/backupNow.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x backupNow.py
# End download commands
```

## Components

* backupNow.py: the main PowerShell script
* pyhesity.py: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```bash
# example
./backupNow.py -v mycluster \
               -u myuser \
               -d mydomain.net \
               -j 'My Backup Job' \
               -w
# end example
```

## Authentication Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to

## Selection Parameters

* -j, --jobname: name of protection job to run
* -o, --objectname: (optional) name of object to backup (repeat this parameter for multiple objects)
* -m, --metadatafile: (optional) path to directive file for backup
* -t, --backupType: (optional) choose one of kRegular, kFull or kLog backup types. Default is kRegular (incremental)

## Policy Overrides

* -l, --localonly: (optional) skip replicas and archivals
* -nr, --noreplica: (optional) skip replicas
* -na, --noarchive: (optional) skip archives
* -k, --keepLocalFor: (optional) days to keep local snapshot (defaults to policy settings)
* -a, --archiveTo: (optional) name of archival target to archive to (defaults to policy settings)
* -ka, --keepArchiveFor: (optional) days to keep in archive (defaults to policy settings)
* -r, --replicateTo: (optional) name of remote cluster to replicate to (defaults to policy settings)
* -kr, --keepReplicaFor: (optional) days to keep replica for (defaults to policy settings)
* -pl, --purgeoraclelogs: (optional) delete Oracle archived logs after log backup (only if backupType == 'kLog')

## Monitoring Parameters

* -w, --wait: (optional) wait for backup run to complete and report result
* -pr, --progress: (optional) display percent complete
* -s, --sleeptimesecs: (optional) seconds to sleep between status queries (default is 120)
* -x, --abortifrunning: (optional) exit if job is already running (default is to wait and run after existing run is finished)
* -f, --logfile: (optional) filename to log output
* -n, --waitminutesifrunning: (optional) exit after X minutes if job is already running (default is 60)
* -cp, --cancelpreviousrunminutes: (optional) cancel previous job run if it's been running for X minutes
* -nrt, --newruntimeoutsecs: (optional) exit after X seconds if new run fails to start (default is 1800)
* -debug, --debug: (optional) display verbose error and state messages
* -ex, --extendederrorcodes: (optional) return extended set of exit codes
* -es, --exitstring: (optional) search for string in pulse logs and exit 0 when found
* -est, --exitstringtimeoutsecs: (optional) timeout searching for string and exit 1 if not found
* -sr, --statusretries: (optional) give up trying to get status update after X tries (default is 30)

## Extended Error Codes

* 0: Successful (no error to report)
* 1: Unsuccessful (backup ended in failure or warning)
* 2: authentication error (failed to authenticate)
* 3: Syntax Error (incorrect command line)
* 4: Timed out waiting for existing run to finish (existing run still running)
* 5: Timed out waiting for new run / status update (failed to get status updates)
* 6: Timed out waiting for new run to appear (new run accepted but not started)

## Using -o (--objectname) Parameter

If the -o parameter is omitted, all objects within the specified job are backed up. To select specific objects to backup, us the -o parameter. The format of the object name varies per object type. For example:

* -o myvm1 (VM)
* -o oracle1.mydomain.net/testdb (Oracle)
* -o sql1.mydomain.net/MSSQLSERVER/proddb (SQL)

Repeat the parameter to include multiple objects.
