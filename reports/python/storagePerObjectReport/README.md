# Generate Estimated Storage Per Object Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/storagePerObjectReport/storagePerObjectReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x storagePerObjectReport.py
# end download commands
```

## Components

* storagePerObjectReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./storagePerObjectReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

To report on multiple clusters:

```bash
# example
./storagePerObjectReport.py -v mycluster1 -v mycluster2 -u myusername -d mydomain.net
# end example
```

To connect through Helios:

```bash
# example
./storagePerObjectReport.py -u myuser@mydomain.net -c mycluster1 -c mycluster2
# end example
```

## Parameters

## Authentication Parameters

* -v, --vip: (optional) one or more names or IPa of Cohesity clustera to connect to (repeat for multiple) default is helios.cohesity.com
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) one or more helios/mcm clusters to connect to (repeat for multiple)
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -y, --growthdays: (optional) show growth over the last X days (default is 7)
* -of: --outfolder: (optional) where to write report html (default is current directory)
* -x, --unit: (optional) KiB, MiB, GiB, or TiB] (default is GiB)
* -n, --numruns: (optional) number of runs per API query (default is 500)
* -s, --skipdeleted: (optional) skip deleted protection groups
* -debug, --debug: (optional) print verbose output

## Column Descriptions - Main Report CSV (`storagePerObjectReport-<date>.csv`)

| Col | Column Name | Description
| --- | --- | ---
| A | **Cluster Name** | The name of the Cohesity cluster from which the data was collected.
| B | **Origin** | Indicates whether the protection group is locally active (`local`) or is a replicated copy from another cluster (`replica`).
| C | **Stats Age (Days)** | How many days have elapsed since the statistics for this object were last refreshed by the cluster. A dash (`-`) indicates the timestamp was unavailable.
| D | **Protection Group** | The name of the Cohesity protection group (backup job) that protects this object. For view-type objects not assigned to a job, this may be a dash (`-`).
| E | **Tenant** | The name of the multi-tenancy organization (tenant) that owns the protection group, if applicable. Empty for non-tenanted objects.
| F | **Storage Domain ID** | The numeric internal identifier of the storage domain (view box) where this object's backup data resides.
| G | **Storage Domain Name** | The human-readable name of the storage domain (view box). Shows `DirectArchive` for cloud-archive-only jobs with no local storage domain.
| H | **Environment** | The backup source environment/workload type (e.g., `VMware`, `Physical`, `SQL`, `Oracle`, `NAS`, `View`, `AWS`, `HyperV`). The leading `k` prefix is stripped from the API value.
| I | **Source Name** | The registered protection source (e.g., vCenter, physical host, NAS server) that owns this object. For objects without a parent source, this is the object's own name.
| J | **Object Name** | The specific name of the protected object (e.g., VM name, database name, volume name, view name).
| K | **Front End Allocated `<units>`** | The allocated/provisioned logical size of the object in the selected units (MiB or GiB). For VMs and physical volumes, this reflects the allocated disk size; for other types, it matches the used logical size.
| L | **Front End Used `<units>`** | The actual logical data size consumed by the object at the source, in the selected units. Represents how much data the object occupies before any backup reduction.
| M | **`<units>` Stored (Before Reduction)** | The amount of data ingested into the backup system before deduplication is applied, in the selected units. Reflects the raw data read from the source.
| N | **`<units>` Stored (After Reduction)** | The amount of data stored after deduplication and compression are applied, in the selected units. Does not include replication factor/erasure coding overhead.
| O | **`<units>` Stored (After Reduction and Resiliency)** | The total physical storage consumed on the cluster, in the selected units, after both data reduction and resiliency overhead (replication factor/erasure coding) are factored in. This is the true on-disk footprint.
| P | **Reduction Ratio** | The data reduction ratio achieved for this object's protection job (e.g., `4.2` means the data occupies roughly 1/4.2 of its original size). Calculated as `(dataIn / dataInAfterDedup) × (dataInAfterDedup / dataWritten)`. Defaults to `1` if stats are unavailable.
| Q | **`<units>` Change Last `<N>` Days (After Reduction and Resiliency)** | The net change in physical storage consumption (after reduction and resiliency) over the configured growth window (default: last 7 days), in the selected units. Positive values indicate growth; negative values indicate shrinkage.
| R | **Snapshots** | The total count of non-log backup snapshots retained for this object across all runs inspected.
| S | **Log Backups** | The total count of transaction log backup snapshots retained for this object (applicable to database workloads such as SQL and Oracle).
| T | **Oldest Backup** | The timestamp of the oldest retained local backup snapshot for this object. A dash (`-`) indicates no backups were found.
| U | **Newest Backup** | The timestamp of the most recent retained local backup snapshot for this object. A dash (`-`) indicates no backups were found.
| V | **Newest DataLock Expiry** | The expiry timestamp of the most recent WORM/DataLock constraint applied to a backup run for this object. A dash (`-`) means no active DataLock exists.
| W | **Archive Count** | The total number of successful archive (cloud/tape vault) runs for this object's protection group.
| X | **Oldest Archive** | The timestamp of the oldest successful archive run for this object's protection group. A dash (`-`) indicates no archives exist.
| Y | **`<units>` Archived** | The total cloud/vault storage consumed by this object across all archive targets, in the selected units. Only populated when `--includearchives` is passed.
| Z | **`<units>` per Archive Target** | A bracketed breakdown of archived storage per named vault target (e.g., `[MyS3Vault]12.3`), showing each archive target's individual consumption in the selected units. Only populated when `--includearchives` is passed.
| AA | **Description** | The free-text description field of the protection group or view, as configured in Cohesity. Empty if no description is set.
| AB | **VM Tags** | Semicolon-separated list of VMware tags assigned to the VM object (e.g., `Environment: Prod; Owner: TeamA`). Only populated for VMware workloads.
| AC | **Object ID** | A composite identifier for the object in the format `clusterID:incarnationID:objectID`, uniquely identifying the object within the Cohesity cluster context.
| AD | **AWS Tags** | Semicolon-separated list of AWS resource tags assigned to the object (e.g., `Name: my-instance; Env: prod`). Only populated for AWS workloads.

---

## Column Descriptions - Cluster Stats CSV (`storagePerObjectReport-<date>-clusterstats.csv`)

This companion file has one row per cluster and gives a storage accounting reconciliation.

| Col | Column Name | Description
| --- | --- | ---
| A | **Cluster Name** | The name of the Cohesity cluster.
| B | **Total Used `<units>`** | The total physical storage consumed across the entire cluster, in the selected units, as reported by the cluster's usage performance stats.
| C | **BookKeeper Used `<units>`** | The amount of physical storage tracked by Cohesity's internal BookKeeper service (chunk metadata layer), in the selected units, sampled from a 30-day time-series average ending at midnight.
| D | **Total Unaccounted Usage `<units>`** | The difference between total cluster usage and BookKeeper-tracked usage, in the selected units. Represents storage that is consumed but not directly attributable to tracked objects.
| E | **Total Unaccounted Percent** | The unaccounted storage expressed as a percentage of total cluster usage.
| F | **Garbage `<units>`** | The amount of storage identified as pending garbage (orphaned/unreferenced chunks awaiting collection) by the cluster's internal garbage metrics, in the selected units.
| G | **Garbage Percent** | Garbage storage expressed as a percentage of total cluster usage.
| H | **Other Unaccounted Usage `<units>`** | Unaccounted usage minus identified garbage, in the selected units. Represents any remaining unexplained storage overhead not yet classified as garbage.
| I | **Other Unaccounted Percent** | Other unaccounted usage expressed as a percentage of total cluster usage.
| J | **Reduction Ratio** | The cluster-wide data reduction ratio, calculated as raw data ingested divided by data after reduction.
| K | **All Objects Front End Size `<units>`** | The sum of front-end logical sizes across all protected objects reported in the main CSV, in the selected units.
| L | **All Objects Stored (After Reduction) `<units>`** | The sum of post-reduction storage across all objects, in the selected units.
| M | **All Objects Stored (After Reduction and Resiliency) `<units>`** | The sum of post-reduction, post-resiliency physical storage across all objects, in the selected units.
| N | **Storage Variance Factor** | A ratio of total cluster physical usage to the sum of per-object stored-after-resiliency values (`clusterUsed / sumObjectsWrittenWithResiliency`). Values significantly above `1.0` indicate storage not accounted for at the object level (untracked data, overhead, etc.).
| O | **Script Version** | The version string of the script that generated this report (e.g., `2026-05-05 (Python)`).
| P | **Cluster Software Version** | The Cohesity software version currently running on the cluster.
