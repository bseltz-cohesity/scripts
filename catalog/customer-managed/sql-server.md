# Customer-Managed — SQL Server

[← Back to Customer-Managed](README.md)

Total scripts: **33**

## Migration (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [migrateSQLDB.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/migrateSQLDB) | PowerShell | 2024-11-04 | This script initiates, syncs, finalizes or lists SQL database migrations. |

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [sqlReprotectWithSourceSideDedup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlReprotectWithSourceSideDedup) | PowerShell | 2026-04-28 | `Note:` This script requires Cohesity 7.3.1 or later |

## Protection & Recovery (25)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [aagFailoverMinder.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/aagFailoverMinder) | PowerShell | 2024-11-04 | This PowerShell script monitors for failover related backup errors and responds by running a new incremental backup. |
| [aagFailoverMonitor.py](https://github.com/cohesity/community-automation-samples/tree/main/python/aagFailoverMonitor) | Python | 2024-11-04 | This python script detects SQL Log backup failures due to log chain breaks and AAG failovers, and run the failed protection group to rest the log chain. |
| [cloneSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/cloneSQL) | PowerShell | 2026-08-09 | This script demonstrates how to perform a SQL Clone Attach using PowerShell. The script takes a thin-provisioned clone of the latest backup of a SQL database and attaches it to a SQL server. |
| [cloneSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/cloneSQL) | Python | 2026-08-18 | This script clones a Microsoft SQL Server database from a Cohesity backup to a target SQL Server instance, with optional point-in-time log replay. |
| [cloneSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/cloneSQLDBs) | PowerShell | 2026-08-09 | This script demonstrates how to perform a SQL Clone Attach using PowerShell. The script takes a thin-provisioned clone of the latest backup of a SQL database and attaches it to a SQL server. |
| [convertFileBasedSQLjobToVolume.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/convertFileBasedSQLjobToVolume) | PowerShell | 2024-11-04 | This PowerShell script converts a file-based SQL protection job to volume-based. |
| [deleteSQLBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/deleteSQLBackups) | PowerShell | 2026-05-29 | This powershell script deletes all local snapshots of a SQL server. |
| [excludeSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/excludeSQLDBs) | PowerShell | 2024-11-04 | This PowerShell script adds exclusions to a SQL server protection group. |
| [excludeSQLDBs.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/excludeSQLDBs) | Python | 2024-11-04 | This script adds or removes exclusions to SQL protection groups. |
| [latestSQLRecoveryPoint.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/latestSQLRecoveryPoint) | PowerShell | 2026-08-10 | This script shows the protection status for an object. |
| [protectSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/protectSQL) | PowerShell | 2026-06-03 | This PowerShell script adds a SQL server to a new or existing SQL protection job. |
| [protectSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/protectSQL) | Python | 2024-11-04 | This script protects SQL. |
| [protectSQLServer.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/protectSQLServer) | Python | 2024-11-04 | This script adds SQL servers to a file-based SQL protection job. |
| [refreshSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/refreshSource) | PowerShell | 2024-11-04 | This script demonstrates how to perform a refresh operation on a protection source. The prime example of where this is useful is if a new virtual machine is created on VMware (or other hypervisor) and you want Cohesity to recognize the new VM. Refresh is automatic on a schedule, but a manual refresh can be executed to speed up the process. The script takes the following parameters: |
| [registerSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/registerSQL) | PowerShell | 2024-11-04 | This PowerShell script registers physical servers as SQL servers. |
| [registerSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/registerSQL) | Python | 2024-12-02 | This script registers physical SQL protection sources. |
| [registerSQLVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/registerSQLVM) | PowerShell | 2025-11-26 | This PowerShell script registers VMs as SQL servers. |
| [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/deprecated/restoreSQL) | PowerShell | 2026-08-10 | This script demonstrates how to perform a restore of a SQL database. The script can restore the database to the original server, or a different server. It can overwrite the existing database or restore with a different database name. |
| [restoreSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/deprecated/restoreSQLDBs) | PowerShell | 2026-08-10 | This script restores one or more (or all) databases from the specified SQL server (not including the system databases). |
| [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) | PowerShell | 2026-06-06 | `Note:` This script requires Cohesity 6.8.1 or later |
| [restoreSQLv2.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/restoreSQLv2) | Python | 2026-09-08 | This script recovers one or more Microsoft SQL Server databases from Cohesity backups (using the v2 recovery API), with support for point-in-time log replay, renaming, alternate instance/server recovery, flat-file recovery, and bulk recovery of an entire SQL server. |
| [sqlFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlFiles) | PowerShell | 2024-12-11 | This script lists the files associated with a SQL database on a server that is registered with Cohesity. |
| [sqlObjectProtectionStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlObjectProtectionStatus) | PowerShell | 2024-11-04 | This PowerShell script creates a CSV formatted report of protection status per SQL server/database. |
| [sqlRecoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlRecoveryPoints) | PowerShell | 2026-08-10 | This PowerShell script lists available recovery points for every protected SQL database in Cohesity. |
| [unprotectSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/unprotectSQL) | PowerShell | 2026-10-09 | This PowerShell script removes a database, instance or server from the selections of an existing SQL server protection group. If the item being removed is not itself explicitly selected but is auto-protected because a parent entity (its instance or server) is selected, the script adds an exclusion filter instead, since there is no explicit selection to remove. If a server or instance is removed and it isn't itself explicitly selected, any of its child instances or databases that are explicitly selected are unselected instead. |

## Reporting & Analytics (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [sqlFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlFileList) | PowerShell | 2024-11-04 | This PowerShell script generates a report of the files associated with SQL databases, for SQL servers registered to Cohesity. Output is written to a CSV file. |
| [sqlHeatmapReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlHeatmapReport) | PowerShell | 2024-11-04 | This PowerShell script will create a heatmap report for all protected SQL databases and send HTML output as an email attachment. |
| [sqlJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlJobSelections) | PowerShell | 2026-02-06 | This PowerShell script generates a CSV report of SQL protection group selections. |
| [sqlProtectedObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlProtectedObjectReport) | PowerShell | 2025-02-04 | This PowerShell script creates a CSV formatted report of objects protected by Cohesity |
| [sqlRestoreReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlRestoreReport) | PowerShell | 2025-06-18 | This script sends an HTML-formatted SQL restore report to Email recipients |
| [sqlStreamCount.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlStreamCount) | PowerShell | 2024-11-04 | This PowerShell script generates a report of the SQL stream count setting for VDI-based SQL protection jobs. Output is written to a CSV file. |
