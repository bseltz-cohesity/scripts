# Replicate Old Snapshots using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script replicates old existing snapshots.

## Components

* [replicateOldSnapshotsV2.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshotsV2/replicateOldSnapshotsV2.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshotsV2/replicateOldSnapshotsV2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x replicateOldSnapshotsV2.py

```

Place both files in a folder together and run the main script like so:

This command will replicate all unexipired snapshots (from all jobs) that have run in the past 31 days (that haven't already been replicated already) and keep them in the replicate for 90 days. First run the command without the -x (--commit) switch, to see what it would do:

```bash
./replicateOldSnapshotsV2.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \ 
                             -r othercluster \
                             -j 'some job'
```

Then if you are happy with what it will do, add the -x (--commit) switch:

```bash
./replicateOldSnapshotsV2.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \ 
                             -r othercluster \
                             -j 'some job' \
                             -x
```

By default, the script will only show what it would do. To actually execute the replication, include the -x switch.

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

* -k, --keepfor: (optional) keep for X days in the replica
* -r, --remotecluster: name of the target cluster
* -j, --jobname: (optional) name of job to replicate (repeat for multiple jobs or use joblist)
* -l, --joblist: (optional) text file of job names to include (one per line) default is all jobs
* -e, --excludelogs: (optional) do not replicate database log backups
* -x, --commit: (optional) perform replications (show only if omitted)
* -resync, --resync: (optional) re-replicate to same cluster (skip previously replicated if omitted)
* -numruns, --numruns: (optional) number of runs per API query (default is 1000)
* -ri, --runid: (optional) specify run ID to replicate
* -n, --newerthan: (optional) replicate runs newer than X days ago
* -o, --olderthan: (optional) replicate runs older than X days ago
* -b, --ifexpiringbefore: (optional) replicate runs that expire less than X days from now
* -a, --ifexpiringafter: (optional) replicate runs that expire more than X days from now
* -rl, --retentionlessthan: (optional) replicate runs with retention less than X days (from backup date)
* -rg, --retentiongreaterthan: (optional) replicate runs with retention greater than X days (from backup date)

## Object Replication

The following parameters allow you to specify objects to replicate. Object-level replication requires Cohesity version 7.3 or later.

* -on, --objectname: (optional) name of object to replicate (repeat for multiple)
* -ol, --objectlist: (optional) text file of object names to replicate (one per line)
