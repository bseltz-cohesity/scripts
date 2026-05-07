# Report Protected Objects using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script generates a report of protected objects. Output is written to a CSV file.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/protectedObjectInventory/protectedObjectInventory.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectedObjectInventory.py
```

## Components

* protectedObjectInventory.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./protectedObjectInventory.py -v mycluster \
                              -u myusername \
                              -d mydomain.net
#end example
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

## Column Definitions for the Output File (`protectedObjectInventory-<clusterName>-<date>.csv`)

| # | Column Header | Description |
| --- | --- | --- |
| A | **Cluster Name** | Name of the Cohesity cluster the object resides on |
| B | **Job Name** | Name of the protection group (backup job) protecting this object |
| C | **Environment** | Workload type (e.g. `VMware`, `SQL`, `Oracle`, `Physical`) |
| D | **Parent** | Name of the registered parent/source that the object belongs to (e.g. vCenter, SQL host); falls back to the object's own name if no parent exists |
| E | **Object Name** | Name of the individual protected object (VM, database, volume, etc.) |
| F | **Object Type** | Granular object type (e.g. `VirtualMachine`, `Database`, `Host`) |
| G | **Object Size (MiB)** | Logical size of the object in MiB as reported by the last backup snapshot |
| H | **Policy Name** | Name of the protection policy applied to the protection group |
| I | **Direct Archive** | Whether Cloud Archive Direct (direct-to-cloud archival without local snapshot) is enabled (`True`/`False`) |
| J | **Last Backup** | Date and time of the most recent backup run for this object |
| K | **Last Status** | Status of the last backup run for this object (e.g. `Success`, `Failed`, `Warning`) |
| L | **Last Run Type** | Type of the last backup run (e.g. `Incremental`, `Full`, `Log`) |
| M | **Job Paused** | Whether the protection group is currently paused (`True`/`False`) |
| N | **Indexed** | Whether indexing is enabled for this object, allowing file-level search and recovery (`True`/`False`) |
| O | **Start Time** | Scheduled start time of the protection group's backup window |
| P | **Time Zone** | Time zone used for the protection group's scheduled start time |
| Q | **QoS Policy** | Quality of Service policy applied to the job (e.g. `BackupHDD`, `BackupSSD`) |
| R | **Priority** | Job priority (e.g. `Low`, `Medium`, `High`) |
| S | **Full SLA** | SLA window in minutes allowed for full backup runs to complete |
| T | **Incremental SLA** | SLA window in minutes allowed for incremental backup runs to complete |
| U | **Incremental Schedule** | Human-readable incremental backup schedule and retention from the policy (e.g. `Every 1 Days keep for 30 Days`) |
| V | **Full Schedule** | Human-readable full backup schedule and retention from the policy (e.g. `Weekly on Sunday keep for 12 Weeks`) |
| W | **Log Schedule** | Human-readable log backup schedule and retention from the policy (applicable to Oracle/SQL workloads) |
| X | **Retries** | Retry configuration from the policy (e.g. `3 times every 30 minutes`) |
| Y | **Replication Schedule** | Human-readable replication schedule and retention defined in the policy, if any |
| Z | **Archive Schedule** | Human-readable archive schedule and retention defined in the policy, if any |
