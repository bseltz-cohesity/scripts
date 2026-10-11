# Customer-Managed — Snapshot Management

[← Back to Customer-Managed](index.md)

Total scripts: **40**

## Cloud Infrastructure (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [powershell_compatible_cleanup_script.ps1](https://github.com/cohesity/community-automation-samples/tree/main/cloud/cleanupSnapshots) | PowerShell | 2026-02-18 | These scripts help cleanup azure snapshots. You can use which ever script is compatible with your environment. |
| [ubuntu_compatible_cleanup_script.sh](https://github.com/cohesity/community-automation-samples/tree/main/cloud/cleanupSnapshots) | Bash/Shell | 2024-11-04 | These scripts help cleanup azure snapshots. You can use which ever script is compatible with your environment. |

## Cluster & System Administration (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [changeLocalRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeLocalRetention) | Python | 2026-07-16 | This script changes the retention of snapshots on the local cluster. |

## Monitoring & Alerting (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [smtptool.py](https://github.com/cohesity/community-automation-samples/tree/main/python/extendRetention) | Python | 2024-11-04 | This python script extends the retention of existing snapshots. It can set new expiration dates for weekly, monthly and yearly snapshots. (smtp functions to send email alerts) |

## Other / Utility (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [extendForCopyTasks.py](https://github.com/cohesity/community-automation-samples/tree/main/python/extendForCopyTasks) | Python | 2024-11-04 | This python script extends the retention of local snapshots that have unfinished copy tasks (replication or archival) |
| [extendNthWeekDay.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/extendNthWeekDay) | PowerShell | 2024-11-04 | This script will extend the retention for the snapshots from the Nth (for example) Saturday of the month. Processed snapshots will be logged to extendLog.txt. |
| [extendRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/extendRetention) | Python | 2024-11-04 | This python script extends the retention of existing snapshots. It can set new expiration dates for weekly, monthly and yearly snapshots. (the main python script) |
| [oldSnapList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/oldSnapList) | Python | 2024-11-04 | This python script will list local snapshots. |

## Protection & Recovery (19)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [changeLocalRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/changeLocalRetention) | PowerShell | 2026-10-07 | This powershell script will change (increase or decrease) the retention of existing snapshots. Note that if you reduce the retention, older backups might immediately get expired! |
| [deletedProtectionGroups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deletedProtectionGroups) | PowerShell | 2024-11-04 | This powershell lists and cleans up deleted protection groups. |
| [deleteJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deleteJobs) | Python | 2024-11-04 | This Python script deletes one or more protection jobs. |
| [deleteObjectBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deleteObjectBackups) | PowerShell | 2026-10-08 | This powershell script searches for a protected object, and deletes all local snapshots of that object. |
| [deleteProtectionJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deleteProtectionJob) | PowerShell | 2024-11-04 | This powershell script deletes a protection job. |
| [deleteServerBackups.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deleteServerBackups) | Python | 2024-11-04 | This script searches for a VM or physical server, and deletes all local snapshots of that VM or server. |
| [expireOldSnapsExceptFirstPerDay.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapsExceptFirstPerDay) | PowerShell | 2024-11-04 | This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period. |
| [expireOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapshots) | PowerShell | 2026-07-16 | This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period. |
| [expireOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots) | Python | 2026-07-16 | This python script will expire old local snapshots. Optionally you can confirm replication before expiring the local snapshot. |
| [expireShortTermSnaps.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireShortTermSnaps) | Python | 2024-11-11 | In the UI, you can schedule backups to be taken multiple times per day and the minimum retention allowed is one day. So if you backup say every 30 minutes, you will accumulate 48 backups. This script will delete backups all but the latest backups that are set to be retained for one day, such that you can reduce the retention to an arbitrary number of minutes and or keep a minimal number of backups. For example you may want to keep only the latest two backups or keep only backups that occurred over the last two hours (or both). |
| [expungeDataSpillage.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expungeDataSpillage) | PowerShell | 2025-09-26 | This powershell script searches for a file, and displays the ProtectionJobs/Objects where the file is stored. You can then select a ProtectionJob/Object and the script will delete all versions of the ProtectionJob/Object where that file exists. The deletion will include the local snapshots plus any archives. Replicas can deleted by running the script against the replica cluster. |
| [fortKnoxLegalHold.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fortKnoxLegalHold) | PowerShell | 2026-08-25 | Contributed by: Guna Chidambaram |
| [legalHold.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHold) | PowerShell | 2024-11-04 | This script add or remove legal hold from a protection run. |
| [legalHold.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHold) | Python | 2026-10-07 | This script add or removes legal hold from a specified backup on the cluster. |
| [legalHoldAll.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldAll) | PowerShell | 2026-04-10 | This script add or remove legal hold from all existing backups. |
| [legalHoldAll.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHoldAll) | Python | 2025-11-06 | This script add or remote legal hold from all backups on the cluster. |
| [legalHoldObject.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldObject) | PowerShell | 2025-12-05 | This script add or remove legal hold for a specified object. |
| [legalHoldObject.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHoldObject) | Python | 2024-12-13 | This script add or removes legal hold to the specified objects. |
| [objectRecoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/objectRecoveryPoints) | PowerShell | 2024-11-04 | This PowerShell script searches for an object and displays the versions available for recovery. |

## Reporting & Analytics (12)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [activeSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshots) | PowerShell | 2025-03-26 | This PowerShell script lists the active snapshot count for every protected object in Cohesity. |
| [activeSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/activeSnapshots) | Python | 2026-05-14 | This python script lists the active snapshot count for every protected object in Cohesity. |
| [activeSnapshotsRemote.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshotsRemote) | PowerShell | 2024-11-04 | This PowerShell script lists the active snapshot count for every protected object that was replicated other Cohesity clusters. The goal is to produce an inventory of snapshots available on replica clusters that are not reachable directly (e.g. vault clusters). |
| [backupInventory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupInventory) | PowerShell | 2024-11-04 | This powershell script reports on every unexpired snapshot and copy that is not expired. The output will be written to a file clusterName-backupInventory.txt. |
| [datalockSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/datalockSnapshots) | PowerShell | 2024-11-04 | This PowerShell script lists snapshots that are datalocked. Output will be written to a CSV file. |
| [jobRecoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobRecoveryPoints) | PowerShell | 2024-11-04 | This PowerShell script lists available recovery points (local and archive) per protection job. Output will be written to a CSV file. |
| [legalHoldList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/legalHoldList) | PowerShell | 2024-11-04 | This powershell script lists protection runs where legal holds are present. Output is saved to a CSV file. |
| [legalHoldList.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/legalHoldList) | Python | 2024-11-04 | This Python script lists protection runs where legal holds are present. Output is saved to a CSV file. |
| [recoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/recoveryPoints) | PowerShell | 2026-08-09 | This PowerShell script lists available local recovery points for every protected object in Cohesity. |
| [recoveryPoints.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/recoveryPoints) | Python | 2026-08-09 | This python script lists available recovery points for every protected object in Cohesity. |
| [snapshotExpirations.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/snapshotExpirations) | PowerShell | 2025-08-15 | This PowerShell script generates a report of local snapshots and their expiration dates. |
| [snapshotList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/snapshotList) | PowerShell | 2026-08-10 | This powershell script displays a list of existing snapshots. |

## Views & Storage (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [selfServiceSnapshotConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/selfServiceSnapshotConfig) | PowerShell | 2025-05-02 | This PowerShell script enables/disables Snapshot Self Service on Cohesity views. |
