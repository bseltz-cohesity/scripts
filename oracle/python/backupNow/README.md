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
./backupNow.py -v mycluster -u myuser -d mydomain.net -j 'My Backup Job' -k 7 -r anothercluster -kr 10 -a myarchivetarget -ka 10 -w
```

```text
Connected!
Running My Backup Job...
New Job Run ID: 60429
Job finished with status: kSuccess
Run URL: https://mycluster/protection/job/32793/run/60429/1555751503627452/protection
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: active directory domain of user (default is local)
* -i, --useApiKey: use API key for authentication
* -j, --jobname: name of protection job to run
* -o, --objectname: name of object to backup (repeat this parameter for multiple objects)
* -y, --usepolicy: use base retention and copy targets from protection policy
* -k, --keepLocalFor: days to keep local snapshot (default is 5 days)
* -a, --archiveTo: name of archival target to archive to
* -ka, --keepArchiveFor: days to keep in archive (default is 5 days)
* -r, --replicateTo: name of remote cluster to replicate to
* -kr, --keepReplicaFor: days to keep replica for (default is 5 days)
* -e, --enable: enable a paused job before running, then disable when done
* -w, --wait: wait for backup run to complete and report result
* -t, --backupType: choose one of kRegular, kFull or kLog backup types. Default is kRegular (incremental)
* -x, --abortifrunning: exit if job is already running (default is to wait and run after existing run is finished)

## Using -o (--objectname) Parameter

If the -o parameter is omitted, all objects within the specified job are backed up. To select specific objects to backup, us the -o parameter. The format of the object name varies per object type. For example:

* -o myvm1 (VM)
* -o oracle1.mydomain.net/testdb (Oracle)
* -o sql1.mydomain.net/MSSQLSERVER/proddb (SQL)

Repeat the parameter to include multiple objects.
