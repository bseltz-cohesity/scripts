# Popular Scripts

Here are some of the most widely used scripts in this repository.

## Backup Now

Initiates the running of a protection group, much like performing a "Run Now" in the UI. This allows users to start the backup at the time of their choosing while leaving the protection group in a paused state, so the PG is never run on a schedule. This is common for SQL DBAs that want to perform some pre processing on their databases before starting the backup.

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow>

## List Backed Up Files

Retrieves a list of files available for restore from a file-based backup. This script enables them to find a specific bak file for restore.

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList>

## Restore Files

Performs file-based restores from physical, NAS backups. Often used in conjunction with backedUpFileList.

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles>

## Protect Windows

Adds windows servers to a file-based protection group

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectWindows>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/protectWindows>

## Protect Linux (*nix)

Adds non-windows servers to a file-based protection group

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux>

## Restore SQL

Performs SQL database restores

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2>

## Restore Oracle

Performs Oracle database restores

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2>

## Restore VMs

Restores VMware VMs. Often used in disaster recovery

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMsV2>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMsV2>

## Popular Scripts for Out-of-Band Replication and Archival

These scripts are often used to replicate or archive out of band (after the fact) to copy existing backups off cluster.

## replicateOldSnapshots

Replicates existing backups

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots>

## archiveOldSnapshots

Archives existing backups

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveOldSnapshots>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/archiveOldSnapshots>

## archiveQueue

Lists and optionally cancels active archive tasks. Often used by support to help customers who are experiencing an archiving backlog.

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/archiveQueue>

## replicationQueue

Lists and optionally cancels active replication tasks. Oten used bty support to help customers who are experiencing a replication backlog.

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue>

## Popular Scripts for Space Reclamation / Change Retention

These scripts are often used by support to help customers free up space on a cluster.

## expireOldSnapshots

Expires old backup to free up space on the cluster

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapshots>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots>

## changeLocalRetention

Changes the retention of local backups

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/changeLocalRetention>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/changeLocalRetention>

## changeArchiveRetention

Changes the retention of archives

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateArchiveRetention>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/python/changeArchiveRetention>

## Popular Scripts for Reporting

## Storage Per Object Report

Reports back-end storage consumption per object, for use in charge back and capacity analysis

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport>

## Helios Reports

Exports data from Helios reports into CSV format for import into customer reporting tools (e.g. Tableau)

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport>

## Protection Runs Report

Details of protection runs, by object

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns>

## Protected Object Report

Details of protected objects

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedObjectReport>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/protectedObjectReport>

## Active Snapshots Report

Summary of available backups per object

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshots>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/activeSnapshots>

## Storage Report

Storage consumption by protection group / view

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageReport>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storageReport>

## Backed Up File Systems Report

Protected file paths

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backedUpFSReport>
* Python: <https://github.com/cohesity/community-automation-samples/tree/main/reports/python/backedUpFSReport>

## Restore Report

Summary of restores

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreReport>

## Detailed Activity Report

Details of recent activity and growth

* PowerShell: <https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/detailedActivityReport>
