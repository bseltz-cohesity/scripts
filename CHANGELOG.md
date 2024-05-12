# Change Log for cohesity/community-automation-samples

## 2024-05-12

* [downloadM365MailboxPST.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadM365MailboxPST) [`New`] Download M365 Mailbox as PST
* [downloadM365MailboxPST.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadM365MailboxPST) [`New`] Download M365 Mailbox as PST

## 2024-05-06

* [dailyObjectStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/dailyObjectStatus) [`Update`] modernized authentication
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Fix`] fixed VM used size edge case
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Fix`] fixed VM used size edge case

## 2024-05-05

* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Fix`] fixed BCT path issue
* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Fix`] fixed BCT path issue
* [cancelRunningObject.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelRunningObject) [`New`] cancel backup for one object
* [cancelRunningObject.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cancelRunningObject) [`New`] cancel backup for one object

## 2024-05-02

* [downloadLatestWarnings.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadLatestWarnings) [`Update`] modernized authentication options
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added -quiet switch to fileDownload function

## 2024-05-01

* [oracleLogDeletionDaysReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleLogDeletionDaysReport) [`Update`] updated to gracefully handle edge cases

## 2024-04-30

* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Fix`] fixed recovery error

## 2024-04-29

* [registerExchange.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerExchange) [`New`] register Exchange application on physical server

## 2024-04-27

* [extendForActiveCopyTasks.py](https://github.com/cohesity/community-automation-samples/tree/main/python/extendForActiveCopyTasks) [`New`] extend local retention for snapshots with active replication/archive tasks

## 2024-04-25

* [changeLocalRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeLocalRetention) [`Fix`] fixed error when runs have active copy tasks
* [protectVMsByCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByCluster) [`New`] auto-protect vSphere clusters/hosts

## 2024-04-24

* [datalockJobList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/datalockJobList) [`Fix`] updated to support recent versions of Cohesity
* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Fix`] fixed filter bug where filter is a list
* [physicalBackupPathsHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsHistoryReport) [`Update`] added outputpath and outputfile parameters

## 2024-04-23

* [changeArchiveRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeArchiveRetention) [`Update`] updated authentication parameters

## 2024-04-22

* [restoreVMFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreVMFiles) [`Fix`] fixed crash on file not found

## 2024-04-21

* [storageReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageReport) [`Fix`] fixed missing replica stats in 7.x
* [storageReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storageReport) [`Fix`] fixed missing replica stats in 7.x

## 2024-04-19

* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) [`
Update`] added -taskName parameter
* [createZDLRAView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createZDLRAView) [`New`] create ZDLRA backup target view
* [protectView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectView) [`Update`] added --clienttype and --catalogview parameters for ZDLRA views

## 2024-04-18

* [physicalBackupPathsHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsHistoryReport) [`Update`] added server name filters and added end time to the output
* [extendRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/extendRetention) [`Update`] increased number of runs to inspect

## 2024-04-13

* [protectionRunsV1Example.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectionRunsV1Example) [`New`] Example of how to use the v1 protectionRuns API
* [protectionRunsV1Example.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectionRunsV1Example) [`New`] Example of how to use the v1 protectionRuns API

## 2024-04-12

* [refreshSource.py](https://github.com/cohesity/community-automation-samples/tree/main/python/refreshSource) [`Update`] added option to read text file of sources to refresh, modernized authentication

## 2024-04-11

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Fix`] Get stats by job ID or name (7.0.1 fix)
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Fix`] Get stats by job ID or name (7.0.1 fix)

## 2024-04-07

* [storageReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageReport) [`Fix`] fixed duplicate entries
* [storageReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storageReport) [`Fix`] fixed duplicate entries

## 2024-04-05

* [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] modernized authentication parameters

## 2024-04-04

* [instantVolumeMount.py](https://github.com/cohesity/community-automation-samples/tree/main/python/instantVolumeMount) [`Fix`] fix run ID selection

## 2024-04-03

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Get stats by job ID
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Get stats by job ID

## 2024-03-31

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Fix`] fixed error reporting

## 2024-03-28

* [registeredSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/registeredSources) [`Update`] expanded search options
* [createSMBView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createSMBView) [`Update`] added option to set share permissions
* [changeLocalRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeLocalRetention) [`Update`] Improved backup type selection options
* [changeLocalRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/changeLocalRetention) [`Update`] Improved backup type selection options

## 2024-03-27

* [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] Added support for SQL

## 2024-03-26

* [oracleDBs.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleDBs) [`Update`] added more columns to output

## 2024-03-24

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added VM Tags column
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Added VM Tags column

## 2024-03-22

* [protectSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/protectSQL) [`Update`] added -s, --showunprotecteddbs option
* [oracleDBs.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleDBs) [`New`] list oracle DBs on registered oracle servers and their protection status

## 2024-03-20

* [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) [`Update`] added runid, newerthan, olderthan parameters
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added channel configuration

## 2024-03-19

* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added CSV output
* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Fix`] fixed System.Object[] in column output

## 2024-03-18

* [listViews.py](https://github.com/cohesity/community-automation-samples/tree/main/python/listViews) [`Update`] modernized authentication

## 2024-03-17

* [heliosAnomalyFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosAnomalyFileList) [`New`] download list of ransomware affected files

## 2024-03-16

* [migrateView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateView) [`New`] Migrate views to another storage domain

## 2024-03-15

* [unprotectedVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectedVMs) [`New`] list unprotected VMs
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Fix`] fixed error reporting

## 2024-03-14

* [pingCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pingCluster) [`New`] enumerate node IPs and ipmi IPs and ping them.
* [clusterIps.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterIPs) [`New`] enumerate all cluster IPs

## 2024-03-13

* [unprotectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectVM) [`Update`] added job filter parameters

## 2024-03-12

* [physicalProtectedBy.py](https://github.com/cohesity/community-automation-samples/tree/main/python/physicalProtectedBy) [`New`] What protection group is protecting this server?
* [archiveMediaInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveMediaInfo) [`New`] Report QStar tape media used for archives

## 2024-03-11

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added Cluster Stats summary ouput

## 2024-03-09

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added clusterStats output file

## 2024-03-08

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] refactored status monitor loop, added -quick mode
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] refactored status monitor loop, added -q --quickdemo mode

## 2024-03-06

* [heliosUsers.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosUsers) [`Updated`] Added created time to report output
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] moved read replica cache wait to after authentication
* [gflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflags) [`Fix`] fixed clear option
* [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) [`Fix`] fixed clear option

## 2024-03-05

* [protectWindows.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectWindows) [`Update`] modernized authentication

## 2024-03-04

* [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Fix`] fixed error "NameError: name 'targetEntity' is not defined" when target server is not found

## 2024-03-03

* [protectSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/protectSQL) [`New`] consolidated script to protect SQL servers, instances, databases

## 2024-03-02

* [protectSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/protectSQL) [`New`] consolidated script to protect SQL servers, instances, databases (protectSQLDB.ps1 and protectSQLServer.ps1 have been replaced)
* [sql](https://github.com/cohesity/community-automation-samples/tree/main/sql) [`Update`] moved SQL scripts into sql/powershell and sql/python folders

## 2024-03-01

* [directiveBackupHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/directiveBackupHistoryReport) [`New`] report directive files used for physical server file-based backups over the past X days
* [excludeSQLDBs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/excludeSQLDBs) [`New`] Add/remove exclusions for SQL protection groups

## 2024-02-29

* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) (PowerShell) [`Update`] added -isilonZoneId parameter
* [pauseProtectionActivity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseProtectionActivity) [`Update`] added wait for service restart at end of script
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added -consolidateDBs option

## 2024-02-28

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added Cluster Used and Reduction columns
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Added Cluster Used and Reduction columns
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added support for helios.gov
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added support for helios.gov
* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Fix`] fixed CDB recovery (overwrite original DB)

## 2024-02-27

* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Fix`] fixed CDB recovery (overwrite original DB)

## 2024-02-24

* [physicalBackupPathsReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsReport) [`Update`] Output to CSV
* [physicalBackupPathsHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsHistoryReport) [`New`] History report of paths backed up from physical servers

## 2024-02-22

* [ccsSlaMonitor.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/ccsSlaMonitor) [`New`] Monitor for SLA violations in CCS

## 2024-02-21

* [protectCCSEC2VMs.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/protectCCSEC2VMs) [`New`] Protect EC2 VMs in CCS
* [nodeStatus.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/nodeStatus) [`New`] report node status

## 2024-02-19

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] expanded existing run string matches
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] expanded existing run string matches

## 2024-02-18

* [clusterProtectionRuns.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns) [`Fix`] fixed units in heading
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] toJson function - handle null input

## 2024-02-16

* [expireOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots) [`Fix`] handle missing clusterName property in replication target history

## 2024-02-15

* [registerPhysical.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerPhysical) [`Update`] added option to set network throttling to X MB/sec and added ability to update existing sources
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added Storage Domain and Front End allocated columns
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Added Storage Domain and Front End allocated columns

## 2024-02-14

* [registerUDA.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerUDA) [`Fix`] added --ostype parameter

## 2024-02-09

* [protectedObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/protectedObjectReport) [`Update`] added support for cloudArchive direct
* [protectedObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedObjectReport) [`Update`] added support for cloudArchive direct

## 2024-02-07

* [findAndRestoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/findAndRestoreFiles) [`Update`] added -targetRegisteredSource to refine selection of -targetObject
* [legalHoldAll.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldAll) [`Update`] report if backup on legal hold is past its intended expiration date

## 2024-02-06

* [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Update`] added support for cloudArchive Direct
* [protectSQLServer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/protectSQLServer) [`Update`] added option to enable source side deduplication (for file-based protection type only)
* [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Fix`] handle missing attemptNum property
* [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) [`Fix`] handle missing attemptNum property

## 2024-02-02

* [restoreSQL-CCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreSQL-CCS) [`Update`] added support for SQL Always On Availability Group datbases

## 2024-02-01

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added support for CloudArchive Direct jobs
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Added support for CloudArchive Direct jobs

## 2024-01-31

* [backedUpFSReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/backedUpFSReport) [`Update`] added -s (--search) and -e (--exactmatch) parameters
* [runsExample.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/runsExample) [`New`] bash example using curl and jq to walk through protection groups and runs

## 2024-01-27

* [restoreReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreReport) [`Update`] added support for cart-based SQL restores

## 2024-01-26

* [restartFailedJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restartFailedJobs) [`New`] find and restart any failed jobs
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`Fix`] added several validation checks for negative search results

## 2024-01-25

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] added support for unicode characters in JSON payloads (affected Windows PowerShell 5.1)

## 2024-01-24

* [epic_vm_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/epic_vm_freeze_thaw) [`New`] VMware Freeze/thaw script for Epic

## 2024-01-22

* [userApiKeys.py](https://github.com/cohesity/community-automation-samples/tree/main/python/userApiKeys) [`New`] List, activate and deactivate user API Keys

## 2024-01-20

* [registeredSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/registeredSources) [`Fix`] fixed windows bug and garbled date format

## 2024-01-19

* [agentStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentStatus) [`Removed`] this script has been superceded by [registeredSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/registeredSources)
* [protectSQLServer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/protectSQLServer) [`Update`] added -unprotectedDBs parameter
* [changeLocalRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/changeLocalRetention) [`Update`] added -jobList parameter
* [protectCcsM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Mailboxes) [`Update`] added support for security groups
* [smbFileOpens](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/smbFileOpens) [`Update`] added path filter

## 2024-01-18

* [legalHoldList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/legalHoldList) [`Update`] moderized authentication

## 2024-01-17

* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`Fix`] added validation of target instance name

## 2024-01-16

* [protectVMsByTag.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByTag) [`Update`] added -noStorageDomain option to support NextGen Cloud Edition

## 2024-01-14

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] integrated legacy access modes
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] integrated legacy access modes

## 2024-01-13

* [detachWindowsAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/detachWindowsAgent) [`New`] detach Windows agent from its Cohesity cluster
* [pauseProtectionActivity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseProtectionActivity) [`Update`] added pause/resume of indexing
* [slaStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/slaStatus) [`Update`] modernized authentication and updated time range parameters
* [registerADSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerADSource) [`New`] register and Active Directory protection source

## 2024-01-11

* [cloneDirectory.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/cloneDirectory) [`New`] clone a directory using bash

## 2024-01-08

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] Added multi-cluster support
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] Added multi-cluster support

## 2024-01-05

* [legalHold.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHold) [`New`] Add/Remove legal hold from specified protection run
* [changeLocalRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeLocalRetention) [`Update`] added options to select specific run for retention change

## 2024-01-03

* [detachLinuxAgent](https://github.com/cohesity/community-automation-samples/tree/main/linux/detachLinuxAgent) (linux) [`New`] detach linux agent from cluster via SSH
* [detachLinuxAgent.exe](https://github.com/cohesity/community-automation-samples/tree/main/windows/detachLinuxAgent) (windows) [`New`] detach linux agent from cluster via SSH
* [detachLinuxAgent.py](https://github.com/cohesity/community-automation-samples/tree/main/python/detachLinuxAgent) (python) [`New`] detach linux agent from cluster via SSH

## 2024-01-02

* [scheduleHealer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/scheduleHealer) [`New`] schedule an Apollo healer run
