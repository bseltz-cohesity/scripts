# Customer-Managed — Replication

[← Back to Customer-Managed](index.md)

Total scripts: **14**

## Protection & Recovery (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [expireOutdatedReplicas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOutdatedReplicas) | Python | 2024-11-04 | When backups run on the local cluster, their retention date is set to X days from the backup start time. If the backup is replicated to a remote cluster, the retention on the remote cluster is set to X days from the replication completion time. So if backup/replication took significant time, the expiration time of the replica could be significantly later than the expiration of the local copy. This is rarely a concern, but in cases where regulatory/policy reqirements demand prompt expiration of the backups, we can expire these "outdated" replicas. |

## Replication, Archive & DR (9)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [monitorReplicationTasks.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/monitorReplicationTasks) | PowerShell | 2024-11-04 | This powershell script monitors replication tasks. |
| [replicateNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateNow) | PowerShell | 2024-11-04 | This powershell script replicates the oldest local snapshot that matches the specified criteria to a remote cluster. |
| [replicateOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots) | PowerShell | 2025-09-24 | This powershell script replicates existing local snapshots to a replication target. This is useful if you have recently created an replication target and want to programatically replicate existing local snapshots. |
| [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) | Python | 2025-06-15 | This python script replicates old existing snapshots. |
| [replicateOldSnapshotsV2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshotsV2) | Python | 2026-04-13 | This python script replicates old existing snapshots. |
| [replicationHistory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationHistory) | PowerShell | 2024-11-04 | This PowerShell script lists historical replciation tasks. |
| [replicationQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue) | PowerShell | 2025-12-03 | This PowerShell script lists the currently active replication tasks, sorted oldest to newest |
| [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) | Python | 2024-11-04 | This python script lists the currently running replication tasks, from oldest to newest. |
| [throttleReplication.py](https://github.com/cohesity/community-automation-samples/tree/main/python/throttleReplication) | Python | 2024-11-04 | This python script adds/removes replication throttles. |

## Reporting & Analytics (3)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [replicationReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/replicationReport) | PowerShell | 2026-06-04 | This PowerShell script generates a report of replication stats, per object, per run, and per day. |
| [replicationReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/replicationReport) | Python | 2026-05-14 | This python script generates a report of replication stats, per object, per run, and per day. |
| [replicationWireStats.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/replicationWireStats) | PowerShell | 2025-04-28 | This powershell script generates a report of replication traffic per day per remote cluster. Output is saved to a CSV file. |

## View DR (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [replicateViews.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2025-05-22 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
