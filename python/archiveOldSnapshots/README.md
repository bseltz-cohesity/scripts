# Archive Old Snapshots using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives old existing snapshots.

## Components

* archiveOldSnapshots.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/archiveOldSnapshots/archiveOldSnapshots.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x archiveOldSnapshots.py

```

Place both files in a folder together and run the main script like so:

This command will archive all unexipired snapshots (from all jobs) that have run in the past 31 days (that haven't already been archived already) and keep them in the archive for 90 days.

```bash
./archiveOldSnapshots.py -v mycluster \
                         -u myuser \
                         -d mydomain.net \ 
                         -t myS3bucket \
                         -n 31 \
                         -k 90
```

You can filter on local jobs only (-l) or replicated jobs only (-r), or you can provide include or exclude jobs via text files (-j ./includejobs.txt or -x ./excludejobs.txt or both).

By default, the script will only show what it would do. To actually execute the archives, include the -f switch.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -p, --password: (optional) password or API key
* -k, --keepfor: (optional) keep for X days in the archive
* -t, --target: name of the external target
* -n, --daysback: (optional) number of days back to look for snapshots to archive (default is 31)
* -j, --joblist: (optional) text file of job names to include (one per line) default is all jobs
* -x, --excludelist: (optional) text file of job names to exclude (one per line)
* -l, --localonly: (optional) only archive local jobs
* -r, --replicasonly: (optional) only archive replica jobs
* -e, --excludelogs: (optional) do not archive database log backups
* -f, --force: (optional) perform archives (show only if omitted)
