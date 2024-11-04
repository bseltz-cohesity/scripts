# Replicate Old Snapshots using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script replicates old existing snapshots.

Note: there's a new experimental V2 version of the script that uses the V2 API. Feedback is welcome.

## Components

* [replicateOldSnapshots.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshots/replicateOldSnapshots.py): the main python script
* [replicateOldSnapshotsV2.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshots/replicateOldSnapshotsV2.py): experimental V2 version
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshots/replicateOldSnapshots.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replicateOldSnapshots/replicateOldSnapshotsV2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x replicateOldSnapshots.py

```

Place both files in a folder together and run the main script like so:

This command will replicate all unexipired snapshots (from all jobs) that have run in the past 31 days (that haven't already been replicated already) and keep them in the replicate for 90 days. First run the command without the -c (--commit) switch, to see what it would do:

```bash
./replicateOldSnapshots.py -v mycluster \
                           -u myuser \
                           -d mydomain.net \ 
                           -r othercluster \
                           -j 'some job'
```

Then if you are happy with what it will do, add the -c (--commit) switch:

```bash
./replicateOldSnapshots.py -v mycluster \
                           -u myuser \
                           -d mydomain.net \ 
                           -r othercluster \
                           -j 'some job' \
                           -c
```

By default, the script will only show what it would do. To actually execute the replication, include the -c switch.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -p, --password: (optional) password or API key
* -k, --keepfor: (optional) keep for X days in the replica
* -r, --remotecluster: name of the target cluster
* -j, --jobname: (optional) name of job to replicate (repeat for multiple jobs or use joblist)
* -l, --joblist: (optional) text file of job names to include (one per line) default is all jobs
* -e, --excludelogs: (optional) do not replicate database log backups
* -c, --commit: (optional) perform replications (show only if omitted)
* -resync, --resync: (optional) re-replicate to same cluster (skip previously replicated if omitted)
* -x, --numruns: (optional) number of runs per API query (default is 1000)
* -ri, --runid: (optional) specify run ID to replicate
* -n, --newerthan: (optional) replicate runs newer than X days ago
* -o, --olderthan: (optional) replicate runs older than X days ago
