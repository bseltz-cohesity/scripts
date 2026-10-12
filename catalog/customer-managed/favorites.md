# Customer-Managed — Favorites

[← Back to Customer-Managed](README.md)

Total scripts: **19**

## Protection & Recovery (7)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) | PowerShell | 2026-09-23 | This PowerShell script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to fimish and report the end status of the job. |
| [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) | Python | 2026-09-23 | This Python script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to finish and report the end status of the job. |
| [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) | PowerShell | 2025-01-07 | This powershell script expires archives older than x days. This is useful if you want to reduce your long term archive retention to reduce storage consumption in the cloud or other archive target. |
| [expireOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapshots) | PowerShell | 2026-07-16 | This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period. |
| [expireOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots) | Python | 2026-07-16 | This python script will expire old local snapshots. Optionally you can confirm replication before expiring the local snapshot. |
| [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) | PowerShell | 2026-10-05 | This powershell script restores files from physical server backups. |
| [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) | Python | 2025-10-16 | This python script restores files from a Cohesity physical server or NAS backup. |

## Replication, Archive & DR (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [archiveOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveOldSnapshots) | PowerShell | 2024-11-04 | This powershell script archives local snapshots. This is useful if you have created an archive target (e.g. AWS S3) and want to programatically archive existing local snapshots. |
| [archiveOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveOldSnapshots) | Python | 2025-05-13 | This python script archives old existing snapshots. |
| [replicateOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots) | PowerShell | 2025-09-24 | This powershell script replicates existing local snapshots to a replication target. This is useful if you have recently created an replication target and want to programatically replicate existing local snapshots. |
| [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) | Python | 2025-06-15 | This python script replicates old existing snapshots. |

## Reporting & Analytics (8)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [clusterProtectionActivities.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionActivities) | PowerShell | 2026-09-18 | This PowerShell script generates a protection activities report. |
| [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) | PowerShell | 2026-08-06 | This PowerShell script generates a protection runs report. |
| [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) | PowerShell | 2026-09-28 | This PowerShell script creates helios reports and outputs CSV format. |
| [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) | Python | 2026-09-28 | This Python script creates helios reports and outputs to HTML, CSV and TSV files. |
| [recoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/recoveryPoints) | PowerShell | 2026-08-09 | This PowerShell script lists available local recovery points for every protected object in Cohesity. |
| [recoveryPoints.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/recoveryPoints) | Python | 2026-08-09 | This python script lists available recovery points for every protected object in Cohesity. |
| [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) | PowerShell | 2026-09-08 | This PowerShell script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate. |
| [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) | Python | 2026-07-10 | This python script creates a report of estimated storage consumption per object. Note that this report performs estimation so is not expected to be completely accurate. |
