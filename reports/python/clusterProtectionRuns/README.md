# Generate Protection Runs Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists the active snapshot count for every protected object in Cohesity.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/clusterProtectionRuns/clusterProtectionRuns.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x clusterProtectionRuns.py
# end download commands
```

## Components

* clusterProtectionRuns.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./clusterProtectionRuns.py -v mycluster -u myusername -d mydomain.net
# end example
```

Or via Helios

```bash
# example
./clusterProtectionRuns.py -u myusername -c mycluster
# end example
```

## Authentication Parameters

* -v, --vip: one or more DNS or IP of the Cohesity cluster to connect to (repeat for multiple)
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -i, --useApiKey: (optional) use API Key authentication
* -pwd, --password: (optional) specify password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) mfa code (only works for one cluster)

## Other Parameters

* -y, --days: (optional) days back to search
* -x, --unit: (optional) KiB, MiB, GiB, or TiB] (default is GiB)
* -t, --objecttype: (optional) filter by type (e.g. kSQL)
* -l, --includelogs: (optional) include log runs
* -n, --numruns: (optional) number of runs per API query (default is 500)
* -lro, --lastrunonly: (optional) only display last run per protection group
* -o, --outputpath: (optional) default is '.'
* -f, --outputfile: (optional) default is protectionRunsReport-date.tsv
* -on, --objectname: (optional) name of server/view to include in report (repeat for multiple)
* -ol, --objectlist: (optional) text file of servers/views to include in report (one per line)

## Column Descriptions

| Col | Column Name | Description
| --- | --- | ---
| A | **Start Time** | The timestamp when the backup snapshot started for this specific object within the protection run.
| B | **End Time** | The timestamp when the backup snapshot completed for this object. If the run was still in progress at report generation time, this reflects the current time rather than a true end time.
| C | **Duration** | The elapsed time of the object's backup snapshot in seconds, calculated as the difference between end and start timestamps. If no end time was recorded, it is measured from the run start to report generation time (i.e. still running).
| D | **status** | The status of the backup of this object (e.g., `Succeeded`, `Failed`, `Running`).
| E | **slaStatus** | Indicates whether the protection run met or missed its SLA window as defined in the protection group. Values are `Met` or `Missed`.
| F | **snapshotStatus** | The status of the individual object's snapshot. Always written as `Active` in this script (since the report can only contain snapshots that are still in retention).
| G | **objectName** | The name of the specific protected object within the run (e.g., VM name, database name, physical host name, volume name).
| H | **sourceName** | The name of the registered protection source that owns this object (e.g., vCenter server, physical host, NAS server). For SQL/Oracle, this is the host name of the database server. Falls back to the object name if no parent source can be resolved.
| I | **groupName** | The name of the Cohesity protection group under which this object was protected.
| J | **policyName** | The name of the protection policy assigned to the protection group. A dash (`-`) is shown for replicated protection groups where the policy cannot be resolved.
| K | **Object Type** | The workload environment type of the protection group (e.g., `kVMware`, `kPhysical`, `kSQL`, `kOracle`, `kNAS`, `kAWS`). Sourced directly from the job's `environment` field.
| L | **backupType** | The type of backup run (e.g., `kRegular` for full/incremental, `kLog` for transaction log backup, `kFull` for forced full). Log runs are excluded by default unless `--includelogs` is passed.
| M | **System Name** | The name of the Cohesity cluster where the protection run executed.
| N | **Logical Size `<unit>`** | The logical (source-side) size of the object at the time of the snapshot, in the selected unit (KiB, MiB, GiB, or TiB). Represents how large the data is before any backup reduction.
| O | **Data Read `<unit>`** | The amount of data read from the source during this backup run for this object, in the selected unit. For incremental runs this reflects only changed data; for full runs it reflects the full data set.
| P | **Data Written `<unit>`** | The amount of data written to the Cohesity cluster storage for this object during this run, in the selected unit. This is post-deduplication at ingest and may be lower than Data Read.
| Q | **Total File Count** | The total number of files enumerated on the source object during the backup run. Primarily meaningful for file-based workloads (NAS, physical file backup). Zero for block-level or database workloads that do not report file counts.
| R | **Backed Up File Count** | The number of files that were actually backed up (transferred) during this run. For incremental runs this will be lower than Total File Count, reflecting only changed or new files.
| S | **Organization Name** | The name of the Cohesity tenant/organization that owns the protection group, if multi-tenancy is configured. Empty for ungrouped or non-tenanted protection groups.
| T | **Tag** | The externally triggered backup tag associated with the run, if the backup was initiated via an external trigger (e.g., an orchestration system that tags runs for tracking purposes). Empty for normally scheduled runs.
