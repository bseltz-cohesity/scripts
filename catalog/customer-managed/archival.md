# Customer-Managed — Archival

[← Back to Customer-Managed](index.md)

Total scripts: **25**

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [heliosUpdateTargetSecretKey.py](https://github.com/cohesity/community-automation-samples/tree/main/python/heliosUpdateTargetSecretKey) | Python | 2024-11-04 | This python script finds external targets that use the specified access key, and updates the secret access key. |

## Protection & Recovery (5)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) | PowerShell | 2025-01-07 | This powershell script expires archives older than x days. This is useful if you want to reduce your long term archive retention to reduce storage consumption in the cloud or other archive target. |
| [registerGCPTargets.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerGCPTargets) | PowerShell | 2024-11-04 | This PowerShell script creates GCP archive targets from a CSV file. |
| [updateAWSExternalTargetAccessKey.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateAWSExternalTargetAccessKey) | PowerShell | 2024-11-04 | This powershell script updates the access key and secret key used to authenticate to an AWS S3 external target (for cloud archive or cloud tier). |
| [updateAWSExternalTargetCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateAWSExternalTargetCredentials) | Python | 2024-11-04 | This python script updates the access key and secret key used to authenticate to an AWS S3 external target (for cloud archive or cloud tier). |
| [updateGCPExternalTargetPrivateKey.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateGCPExternalTargetPrivateKey) | PowerShell | 2024-11-04 | This powershell updates the private key used to authenticate to a GCP external target (for cloud archive or cloud tier). |

## Replication, Archive & DR (11)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [archiveEndOfMonth.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveEndOfMonth) | Python | 2024-11-04 | This python script archives an existing local snapshot taken on the last day of the month. |
| [archiveNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveNow) | PowerShell | 2024-11-04 | This powershell script archives the latest snapshot of all (or selected) jobs to the specified criteria to an external target. |
| [archiveNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveNow) | Python | 2024-11-04 | This python script archives the latest local snapshot from the specified jobs. |
| [archiveOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveOldSnapshots) | PowerShell | 2024-11-04 | This powershell script archives local snapshots. This is useful if you have created an archive target (e.g. AWS S3) and want to programatically archive existing local snapshots. |
| [archiveOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveOldSnapshots) | Python | 2025-05-13 | This python script archives old existing snapshots. |
| [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) | PowerShell | 2025-02-13 | This PowerShell script lists the currently active archive tasks and outputs to a CSV. |
| [archiveQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveQueue) | Python | 2024-11-04 | This python script lists the currently running archive tasks, from oldest to newest. |
| [cancelArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelArchives) | PowerShell | 2024-11-04 | This PowerShell script lists the currently active archive tasks and outputs to a CSV. |
| [changeArchiveRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeArchiveRetention) | Python | 2025-06-26 | This script changes the retention of archived snapshots. |
| [restartArchives.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restartArchives) | Python | 2024-11-04 | This python script restarts canceled or failed archive tasks. |
| [updateArchiveRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateArchiveRetention) | PowerShell | 2025-02-21 | This script will update the retention of existing archives. Note that for Cohesity versions prior to 6.5.1b, the local snapshots must still exist for archive retention to be modified. |

## Reporting & Analytics (8)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [archivedObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archivedObjects) | PowerShell | 2024-11-04 | This PowerShell script lists the latest backup data and latest archive date for every protected object in the Cohesity cluster. |
| [archivedSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/archivedSnapshots) | Python | 2024-11-04 | This Python script generates a report of protection job runs and their expiry and archival status and outputs to a CSV file. |
| [archiveInventory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveInventory) | PowerShell | 2026-05-07 | This PowerShell script reports on currently archived backups and outputs to a CSV file. |
| [archiveMediaInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveMediaInfo) | PowerShell | 2026-04-28 | This PowerShell script reports on the tapes where archives are stored. |
| [archiveVersionReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveVersionReport) | PowerShell | 2024-11-04 | This PowerShell script reports on the cloud archive version (v1 or v2) in use per protection group. |
| [cloudArchiveDirectStats.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/cloudArchiveDirectStats) | PowerShell | 2024-11-04 | This PowerShell script gathers cloud archive direct size and transfer stats. |
| [powerBI-helios-externalTargetUsage.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/powerBI/python/powerBI-helios-externalTargetUsage) | Python | 2024-11-04 | This python script imports external target storage consumption from all Helios connected clusters into Power BI |
| [snapshotArchiveInventory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/snapshotArchiveInventory) | PowerShell | 2026-08-04 | This PowerShell script inventories every local snapshot, archive copy, and replicated-in copy that is currently available for recovery across one or more Cohesity clusters (directly, or Helios/MCM-managed). Each recovery point is reported at the object level, along with where it lives (local, archive target, or source cluster) and when it expires. |
