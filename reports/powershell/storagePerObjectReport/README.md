# Generate Estimated Storage Per Object Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storagePerObjectReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storagePerObjectReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/storagePerObjectReport/storagePerObjectReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./storagePerObjectReport.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

To report on multiple clusters:

```powershell
# example
./storagePerObjectReport.ps1 -vip mycluster1, mycluster2 -username myusername -domain mydomain.net
# end example
```

To connect through Helios:

```powershell
# example
./storagePerObjectReport.ps1 -username myuser@mydomain.net -clusterName mycluster1, mycluster2
# end example
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -numRuns: (optional) number of runs per API query (default is 1000)
* -growthDays: (optional) number of days to measure recent growth (default is 7)
* -skipDeleted: (optional) skip deleted protection groups
* -unit: (optional) MiB, GiB, TiB, MB, GB or TB (default is GiB)
* -outfileName: (optional) specify name for output csv file
* -consolidateDBs: (optional) hide Oracle and SQL databases and only show the parent host
* -includeArchives: (optional) get per object stats for external targets
* -environments: (optional) one or more environment types to include (comma separated) e.g. kSQL, kVMware

## Column Descriptions - Main Report CSV (`storagePerObjectReport-<date>.csv`)

| # | Column Name | Description
| --- | --- | ---
| 1 | **Cluster Name** | The name of the Cohesity cluster where the protection group resides.
| 2 | **Origin** | Whether the backup is locally created (`local`) or replicated from another cluster (`replica`).
| 3 | **Stats Age (Days)** | How many days have elapsed since the storage statistics for this object were last updated. A dash (`-`) means the timestamp was unavailable or zero.
| 4 | **Protection Group** | The name of the Cohesity Protection Group (backup job) that protects this object.
| 5 | **Tenant** | The name of the tenant (organization) associated with the Protection Group, if multi-tenancy is in use.
| 6 | **Storage Domain ID** | The internal numeric ID of the Storage Domain (View Box) where the backups are stored.
| 7 | **Storage Domain Name** | The human-readable name of the Storage Domain. For Direct-to-Cloud Archive jobs this shows `DirectArchive`.
| 8 | **Environment** | The Cohesity environment/workload type for the protected object (e.g., `kVMware`, `kSQL`, `kOracle`, `kPhysical`, `kView`, `kAWS`, etc.).
| 9 | **Source Name** | The registered protection source that owns this object — for example, the vCenter server, SQL host, or physical server. For objects with no parent, this mirrors the Object Name.
| 10 | **Object Name** | The name of the individual protected object — a VM name, database name, volume, or Cohesity View name.
| 11 | **Front End Allocated `<unit>`** | The allocated/provisioned size of the object on the source (e.g., the provisioned disk size of a VM). This is the "thin provisioned maximum" size, not the amount actually written. Units are controlled by the `-unit` parameter (default GiB).
| 12 | **Front End Used `<unit>`** | The amount of data actually used/consumed on the source side at the time of the most recent snapshot. For VMs this reflects logical used bytes; for CAD objects it reflects the archive logical size. Same unit as above.
| 13 | **`<unit>` Stored (Before Reduction)** | Estimated data ingested from the source before any deduplication or compression is applied. Derived by apportioning the job-level `dataInBytes` metric by the object's proportional weight within the job.
| 14 | **`<unit>` Stored (After Reduction)** | Estimated storage consumed after deduplication and compression, but before the resiliency overhead (replication factor or erasure coding) is applied.
| 15 | **`<unit>` Stored (After Reduction and Resiliency)** | Estimated total physical storage consumed on the cluster, accounting for both data reduction (dedup + compression) and the resiliency overhead of the Storage Domain policy. This is the most representative "true disk footprint" column.
| 16 | **Reduction Ratio** | The combined data reduction ratio (deduplication × compression) achieved for this object's Protection Group. A value of `2.5` means the data was reduced to 1/2.5 of its original size.
| 17 | **`<unit>` Change Last `<N>` Days (After Reduction and Resiliency)** | The estimated growth in physical storage over the last N days (controlled by `-growthDays`, default 7). Calculated from bytes read during recent runs, reduced by the job reduction ratio, then multiplied by the resiliency factor.
| 18 | **Snapshots** | The total number of full/incremental backup snapshots retained for this object across all runs scanned.
| 19 | **Log Backups** | The number of log backup runs (e.g., SQL transaction log or Oracle archive log backups) retained for this object.
| 20 | **Oldest Backup** | The timestamp of the oldest retained backup snapshot for this object (the recovery point furthest back in time).
| 21 | **Newest Backup** | The timestamp of the most recent retained backup snapshot for this object.
| 22 | **Newest DataLock Expiry** | The expiry date/time of the most recent DataLock (WORM/immutability) constraint on a snapshot for this object. A dash (`-`) means no active DataLock exists.
| 23 | **Archive Count** | The total number of successful archive (cloud/tape) operations recorded across all runs for this Protection Group. Reported at the job level, not per-object.
| 24 | **Oldest Archive** | The timestamp of the oldest successful archive run for this Protection Group (job-level, not per-object).
| 25 | **`<unit>` Archived** | The estimated amount of data for this object stored in external archive targets (cloud vaults). Derived by weighting the vault's job-level storage consumed by this object's proportional share. Only populated when `-includeArchives` is specified.
| 26 | **`<unit>` per Archive Target** | A breakdown of archived storage by individual archive target, formatted as `[VaultName]<size>` entries. Only populated when `-includeArchives` is specified.
| 27 | **Description** | The free-text description field of the Protection Group, as entered by an administrator.
| 28 | **VM Tags** | For VMware objects: a semicolon-delimited list of VMware tags assigned to the VM at the time of the last backup scan. Empty for non-VMware workloads.
| 29 | **Object ID** | A fully-qualified internal identifier for the object in the format `<ClusterID>:<IncarnationID>:<ObjectID>`. Useful for correlating records across reports or API calls.
| 30 | **AWS Tags** | For AWS objects: a semicolon-delimited list of AWS resource tags (`key: value` pairs) assigned to the protected EC2 instance or resource. Empty for non-AWS workloads.

---

## Column Descriptions - Cluster Stats CSV (`storagePerObjectReport-<date>-clusterstats.csv`)

This companion file has one row per cluster and gives a storage accounting reconciliation.

| # | Column Name | Description
| --- | --- | ---
| 1 | **Cluster Name** | The name of the Cohesity cluster.
| 2 | **Total Used `<unit>`** | Total physical storage used on the cluster as reported by the cluster's performance stats (`totalPhysicalUsageBytes`). This is the ground-truth number from the cluster.
| 3 | **BookKeeper Used `<unit>`** | Physical bytes tracked by the cluster's internal BookKeeper service (`BookkeeperChunkBytesPhysical`), which accounts for all known data chunks. Used as the basis for unaccounted storage calculations.
| 4 | **Total Unaccounted Usage `<unit>`** | The difference between Total Used and BookKeeper Used — storage consumed on disk that is not attributed to any tracked data chunk. Includes garbage, metadata, and other overhead.
| 5 | **Total Unaccounted Percent** | Total Unaccounted Usage expressed as a percentage of Total Used.
| 6 | **Garbage `<unit>`** | Bytes identified as garbage (orphaned, unreferenced chunks awaiting garbage collection) via the cluster's `kMorphedGarbageBytes` metric.
| 7 | **Garbage Percent** | Garbage bytes as a percentage of Total Used.
| 8 | **Other Unaccounted `<unit>`** | Unaccounted storage that is not classified as garbage — typically metadata, internal system files, or overhead not yet reconciled by BookKeeper. Calculated as Total Unaccounted minus Garbage.
| 9 | **Other Unaccounted Percent** | Other Unaccounted expressed as a percentage of Total Used.
| 10 | **Reduction Ratio** | The cluster-wide data reduction ratio (`dataInBytes / dataInBytesAfterReduction`), representing the overall dedup+compression effectiveness across all workloads.
| 11 | **All Objects Front End Size `<unit>`** | The sum of logical/front-end sizes across all objects reported in the main CSV. Useful for cross-checking coverage.
| 12 | **All Objects Stored (After Reduction) `<unit>`** | The sum of all per-object "Stored After Reduction" values — total estimated deduplicated+compressed footprint before resiliency, summed across all objects.
| 13 | **All Objects Stored (After Reduction and Resiliency) `<unit>`** | The sum of all per-object "Stored After Reduction and Resiliency" values — the script's best estimate of total physical footprint for all tracked objects. Compare to Total Used to assess coverage.
| 14 | **Storage Variance Factor** | The ratio of actual cluster physical usage to the script's calculated sum of all objects' post-resiliency storage (`clusterUsedBytes / sumObjectsWrittenWithResiliency`). A value near `1.0` means the script accounts for nearly all storage. Values significantly above `1.0` indicate unaccounted overhead (metadata, garbage, etc.).
| 15 | **Script Version** | The version string of the script that generated this report (e.g., `2026-01-15 (PowerShell)`).
| 16 | **Cluster Software Version** | The Cohesity DataProtect software version running on the cluster at the time the report was generated.
