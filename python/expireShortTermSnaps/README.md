# Expire Short Term Snaps Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

In the UI, you can schedule backups to be taken multiple times per day and the minimum retention allowed is one day. So if you backup say every 30 minutes, you will accumulate 48 backups. This script will delete backups all but the latest backups that are set to be retained for one day, such that you can reduce the retention to an arbitrary number of minutes and or keep a minimal number of backups. For example you may want to keep only the latest two backups or keep only backups that occurred over the last two hours (or both).

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireShortTermSnaps/expireShortTermSnaps.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x expireShortTermSnaps.py
# end download commands
```

## Components

* [expireShortTermSnaps.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/expireShortTermSnaps/expireShortTermSnaps.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./expireShortTermSnaps.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -j 'My Backup Job 1' \
                          -j 'My Bacjup Job 2' \
                          -n 2 \
                          -m 120 \
                          -e
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of job to include (repeat for multiple jobs)
* -l, --joblist: (optional) text file containing job names to include (one per line)
* -n, --numsnapstokeep: (optional) minimum number of snaps to keep (defaults to 2)
* -m, --minutestokeep: (optional) minimum age of snapshots to delete (default is 120)
* -e, --expire: (optional) perform expirations (otherwise test mode only)
* -f, --maxlogfilesize: (optional) trim log if log reaches this size (default is 100000 bytes)

## Scheduling with CRON

The script can be run on a schedule so that the number of short term snaps is reduced periodically. Presumably you would run thie script hourly. You can use CRON to schedule the script.

First, create a bash shell script that calls the script like the following:

```bash
#!/bin/bash
cd /home/cohesity/scripts
./expireShortTermSnaps.py -v mycluster -u myuser -d mydomain.net -j 'My Backup Job 1' -j 'My Backup Job 2' -n 2 -m 120 -e
```

Then run the script via CRON like so:

```bash
0 * * * * /home/cohesity/scripts/myscript.sh >> /home/cohesity/scripts/cron.log 2>&1
```
