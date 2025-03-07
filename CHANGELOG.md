# Change Log for cohesity/community-automation-samples

* [`2025-03-07`] [restoreCcsM365Site.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreCcsM365Site) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-07`] [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-07`] [generateAndUploadClusterCerts.py](https://github.com/cohesity/community-automation-samples/tree/main/python/generateAndUploadClusterCerts) [`Update`]
* [`2025-03-06`] [restoreCcsM365OneDrive.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreCcsM365OneDrive) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-06`] [protectCcsM365OneDrive.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365OneDrive) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-06`] [migrateUsersAndGroups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateUsersAndGroups) [`Update`]
* [`2025-03-06`] [heliosUsers.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosUsers) [`Update`] added domain column to output file
* [`2025-03-06`] [restoreCcsM365Mailbox.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreCcsM365Mailbox) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-06`] [protectCcsM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Mailboxes) [`Update`] added support for Microsoft 365 Backup Storage
* [`2025-03-06`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`]
* [`2025-03-06`] [restoreCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreCassandra) [`New`] restore Cassandra keyspaces/tables
* [`2025-03-05`] [cancelCcsProtectionRuns.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/cancelCcsProtectionRuns) [`New`] cancel protection runs in CCS
* [`2025-03-04`] [backupNowCcs.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/backupNowCcs) [`New`] on demand backups of protected objects in CCS
* [`2025-03-04`] [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`]
* [`2025-03-04`] [recoverFileScheduled.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverFileScheduled) [`Update`]
* [`2025-03-04`] [gflagList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflagList)  [`Update`]
* [`2025-03-04`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs)  [`Update`]
* [`2025-03-04`] [replicationQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue)  [`Update`]

## 2025-02-25

* [copySecurityConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copySecurityConfig) copy account security configuration from one cluster to another

## 2025-02-14

* [maintenance.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/maintenance) [`New`] set maintenance mode on protection sources

## 2025-02-11

* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] improved API queries
* [restoreFilesReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/restoreFilesReport) [`Update`] updated column headings
* [restoreFilesReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreFilesReport) [`Update`] modernized authentication and updated column headings

## 2025-02-10

* [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] improved API queries
* [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) [`Update`] added VM recovery point

## 2025-02-09

* [recoverNASVolume.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverNASVolume) [`Update`] updated to v2 API and added SMB share permissions and subnet allow list controls
* [recoverNASVolume.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverNASVolume) [`Update`] added recover as View and SMB share permissions and subnet allow list controls

## 2025-02-08

* [registerGenericNas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerGenericNas) [`Update`] modernized authentication
* [registerGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerGenericNas) [`Update`] modernized authentication
* [protectGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectGenericNas) [`Update`] modernized authentication

## 2025-02-07

* [registerDB2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerDB2) [`New`] register DB2 UDA protection source

## 2025-02-06

* [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] added support for multiple datastores
* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added support for multiple datastores

## 2025-02-05

* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) [`
Fix`] added pagination to file search
* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Fix`] added pagination to file search

## 2025-02-04

* [sqlProtectedObjectReport](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlProtectedObjectReport) [`Update`] improved protectionSources query performance

## 2025-02-03

* [protectionRunsReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectionRunsReport) [`Update`] added job ID to output

## 2025-02-02

* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] modernized authentication
* [backedUpFSReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backedUpFSReport) [`Update`] modernized authentication
* [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileFiles) [`Update`] modernized authentication

## 2025-01-31

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed /v2/users/session authentication

## 2025-01-30

* [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) [`New`] report on VM recoveries

## 2025-01-27

* [updateCcsRdsCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [updateCcsRdsCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added region parameter to api function

## 2025-01-23

* [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) [`Update`] Added CSV output and total folder size
* [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Update`] Added CSV output and total folder size

## 2025-01-17

* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added -coe, --continueonerror option, -w, --wait option, updated folder enumeration

## 2025-01-16

* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added -env, --environment, -on, --objectname, -ol, --objectlist pre-filtering parameters

## 2025-01-15

* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added overwrite handaling

## 2025-01-14

* [vmRecoveryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/vmRecoveryReport) [`New`] report on VM recoveries
* [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Fix`] fixed issue with nested sites

## 2025-01-13

* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/heliosV2/powershell/heliosCSVReport) [`Update`] added filters functionality

## 2025-01-10

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added `Get-Runs` function
* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] updated to use the Get-Runs function
* [runningJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/runningJobs) [`Update`] updated to use the Get-Runs function
* [maintenance.py](https://github.com/cohesity/community-automation-samples/tree/main/python/maintenance) [`New`] set maintenance mode on protection sources

## 2025-01-08

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added getRuns function

## 2025-01-07

* [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) [`Fix`] solved paging issue
* [fixRedundantProtection.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fixRedndantProtection) [`Update`] added filtering for M365
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added --noalert option

## 2025-01-02

* [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] added `-backupType` parameter

## Old Change Logs

* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2023.md)
