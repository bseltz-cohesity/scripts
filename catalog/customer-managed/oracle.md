# Customer-Managed — Oracle

[← Back to Customer-Managed](README.md)

Total scripts: **25**

## Migration (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [migrateOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/migrateOracle) | Python | 2025-10-07 | This script migrates a previously restored Oracle database that was instantly restored but not migrated yet. |

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [updateOracleLogDeletion.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/updateOracleLogDeletion) | Python | 2024-11-04 | This script updates the number of days to retain Oracle archived logs. |

## Protection & Recovery (21)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cloneOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracle) | PowerShell | 2026-08-09 | This script demonstrates how to perform an Oracle Clone Attach using PowerShell. The script takes a thin-provisioned clone of the latest backup of an Oracle database and attaches it to an Oracle server. |
| [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) | Python | 2026-08-14 | This script demonstrates how to perform an Oracle Clone Attach using Python. The script takes a thin-provisioned clone of the latest backup of an Oracle database and attaches it to an Oracle server. |
| [cloneOracleBackupsToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracleBackupsToView) | PowerShell | 2024-11-04 | This powershell script clones backup files to a Cohesity view. |
| [cloneOracleBackupsToView.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracleBackupsToView) | Python | 2024-11-04 | This script clones Oracle backups to a user-accessible Cohesity View |
| [mountOracleAsView.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/mountOracleAsView) | Python | 2024-11-04 | This script mounts an Oracle DB backup as a Cohesity View |
| [oracleDBs.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleDBs) | Python | 2024-12-18 | This script lists Oracle databases of servers registered on Cohesity and outputs to a CSV file. |
| [oracleProtectionStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/oracleProtectionStatus) | PowerShell | 2025-05-09 | This script reports on the protection status of Oracle databases for ORacle servers registered on Cohesity. Output is written to a CSV file. |
| [protectOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/protectOracle) | PowerShell | 2024-11-04 | This powershell script protects Oracle Databases. |
| [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) | Python | 2026-01-07 | This script protects Oracle databases. |
| [registerOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/registerOracle) | PowerShell | 2024-11-04 | This PowerShell script registers physical servers as Oracle servers. |
| [registerOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/registerOracle) | Python | 2026-01-07 | This script registers Oracle protection sources. |
| [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) | PowerShell | 2025-05-13 | This script performs an restore of an Oracle database. The script can restore the database to the original server, or a different server. |
| [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) | Python | 2026-04-20 | This script performs an restore of an Oracle database. The script can restore the database to the original server, or a different server. |
| [restoreOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle) | PowerShell | 2026-08-10 | This script demonstrates how to perform an restore of an Oracle database. The script can restore the database to the original server, or a different server. It can overwrite the existing database or restore with a different database name. |
| [restoreOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle) | Python | 2026-08-10 | This script demonstrates how to perform an Oracle restore using Python. |
| [restoreOracleLogs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracleLogs) | PowerShell | 2024-12-01 | This script performs a restore of Oracle archive logs. |
| [restoreOracleLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracleLogs) | Python | 2024-12-01 | This script performs a restore of Oracle archive logs. |
| [unprotectOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/unprotectOracle) | PowerShell | 2024-11-04 | This script unprotects Oracle servers or databases. Note: it will delete the protection job is no servers are left protected by the job. |
| [unprotectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/unprotectOracle) | Python | 2024-11-04 | This script unprotects Oracle servers or databases. Note: it will delete the protection job is no servers are left protected by the job. |
| [updateOracleDbCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/updateOracleDbCredentials) | PowerShell | 2024-11-04 | This PowerShell script sets the database username and password for an Oracle protection source. |
| [updateOracleDbCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/updateOracleDbCredentials) | Python | 2024-11-04 | This Python script sets the database username and password for an Oracle protection source. |

## Reporting & Analytics (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [oracleBackupReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleBackupReport) | Python | 2025-07-25 | This script generates a report of oracle backups and outputs to a CSV |
| [oracleLogDeletionDaysReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleLogDeletionDaysReport) | Python | 2024-11-04 | This script reports the number of days to retain Oracle archived logs for each protected Oracle database. |
