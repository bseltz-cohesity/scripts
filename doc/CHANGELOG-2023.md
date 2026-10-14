# 2023 Change Log for cohesity/community-automation-samples

## 2023-12-30

* [deployLinuxAgent](https://github.com/cohesity/community-automation-samples/tree/main/linux/deployLinuxAgent) (linux) [`New`] deploy linux agent via SSH
* [deployLinuxAgent.exe](https://github.com/cohesity/community-automation-samples/tree/main/windows/deployLinuxAgent) (windows) [`New`] deploy linux agent via SSH
* [deployLinuxAgent.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deployLinuxAgent) (python) [`New`] deploy linux agent via SSH

## 2023-12-29

* [agentGflags](https://github.com/cohesity/community-automation-samples/tree/main/linux/agentGflags) (linux) [`New`] set agent gflags via SSH
* [agentGflags.exe](https://github.com/cohesity/community-automation-samples/tree/main/windows/agentGflags) (windows) [`New`] set agent gflags via SSH
* [agentGflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/agentGflags) (python) [`New`] set agent gflags via SSH

## 2023-12-23

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Update`] added --daystokeep and --showfinished parameters
* [replicationQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue) [`Update`] added --daystokeep parameter

## 2023-12-22

* [pwstore](https://github.com/cohesity/community-automation-samples/tree/main/linux/pwstore) (linux) [`New`] compiled executable to store and retrieve a password from an encrypted file
* [pwstore.exe](https://github.com/cohesity/community-automation-samples/tree/main/windows/pwstore) (windows) [`New`] compiled executable to store and retrieve a password from an encrypted file

## 2023-12-21

* [viewDR](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) [`Update`] added -emailMfaCode option to the viewDR scripts

## 2023-12-19

* [extendRetention](https://github.com/cohesity/community-automation-samples/tree/main/windows/extendRetention) (windows) [`New`] binary version of extendRetention for windows
* [extendRetention](https://github.com/cohesity/community-automation-samples/tree/main/windows/extendRetention) (linux) [`New`] binary version of extendRetention for linux

## 2023-12-18

* [recoverVMsV2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMsV2) [`Update`] added support for nested VM folders
* [recoverVMsV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMsV2) [`Update`] added support for nested VM folders
* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Fix`] empty results when report doesn't include an environment column

## 2023-12-17

* READMEs: [`Update`] added links to raw files for copy/paste access

## 2023-12-16

* [copyRoles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/copyRoles) [`New`] python script to copy custom roles from one Cohesity cluster to another

## 2023-12-15

* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/windows/restoreFiles) (windows) [`Update`] added --registeredsource and --registeredtarget parameters to filter on registered NAS sources
* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/aix/restoreFiles) (aix) [`Update`] added --registeredsource and --registeredtarget parameters to filter on registered NAS sources
* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/linux/restoreFiles) (linux) [`Update`] added --registeredsource and --registeredtarget parameters to filter on registered NAS sources
* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) (python) [`Update`] added --registeredsource and --registeredtarget parameters to filter on registered NAS sources
* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) (PowerShell) [`Update`] added -registeredSource and -registeredTarget parameters to filter on registered NAS sources

## 2023-12-14

* [unprotectCcsObjects.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/unprotectCcsObjects) [`New`] python script to perform final backup and unprotect protected objects in CCS
* [createS3View.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createS3View) [`New`] create an S3 view using python

## 2023-12-13

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] re-ordered apiauth parameters to force positional parameter to be interpreted as the password
* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] disallow positional parameters
* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) [`Update`] disallow positional parameters
* [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Update`] disallow positional parameters

## 2023-12-11

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] added extended error code 9 'SuccessWithWarning'
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] added extended error code 9 'SuccessWithWarning'

## 2023-12-07

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Fix`] case insensitive match on jobname
* [prometheusClusterStatsExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/Prometheus/ClusterStats) [`Update`] Added morphed garbage metric

## 2023-12-06

* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Update`] added -excludeEnvironment parameter
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`Fix`] fixed -noStop error (-noStop is now deprecated)
* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Fix`] fixed order of pfile parameters when overriding existing parameters

## 2023-12-05

* [updateJobSettings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateJobSettings) [`Update`] added -q, --noquiesce option
* [gflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflags) [`Fix`] service restart bug
* [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) [`Fix`] service restart bug

## 2023-12-04

* [downloadCCSAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/downloadCCSAgent) [`New`] PowerShell script to download CCS agents
* [downloadCCSAgent.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/downloadCCSAgent) [`New`] Python script to download CCS agents
* [protectLinux.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux) [`Fix`] Error when creating new job

## 2023-12-03

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added support for raw URL

## 2023-12-01

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added -noDomain switch to apiauth function to support SaaS connector
* [enableSaaSconnectorRT.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/enableSaaSconnectorRT) [`Fix`] updated to support recent cohedity-api.ps1 versions

## 2023-11-30

* [updateJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJob) [`Update`] added -newName (rename function)

## 2023-11-29

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Fix`] fixed hang on object not in job run
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Fix`] fixed hang on object not in job run
* [adHocProtectVM.py](https://github.com/cohesity/community-automation-samples/tree/main/python/adHocProtectVM) [`Update`] rewrite to honor policy defaults

## 2023-11-28

* [resqtoreSQL-CCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreSQL-CCS) [`New`] Restore SQL DBs from CCS
* [cloneOracleBackupsToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracleBackupsToView) [`New`] Clone Oracle Backups to an SMB view

## 2023-11-27

* [restoreOneDriveFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreOneDriveFiles) [`New`] Restore OneDrive files/folders

## 2023-11-26

* [gflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflags) [`Update`] switched to modern API
* [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) [`Update`] switched to modern API

## 2023-11-25

* [copyCerts.py](https://github.com/cohesity/community-automation-samples/tree/main/python/copyCerts) [`New`] copy CA certificates from one cluster to another
* [copyCerts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copyCerts) [`New`] copy CA certificates from one cluster to another

## 2023-11-23

* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Update`] added support for instant recovery
* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Update`] added support for instant recovery

## 2023-11-22

* [supportChannel.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/supportChannel) [`New`] PowerShell script to enable / disable support channel
* [supportChannel.py](https://github.com/cohesity/community-automation-samples/tree/main/python/supportChannel) [`New`] Python script to enable / disable support channel

## 2023-11-21

* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`Update`] added -commit parameter and removed -exitWithoutRestore parameter
* [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [restoreOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [cloneOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracle) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [cloneSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/cloneSQL) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [cloneSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/cloneSQLDBs) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [migrateSQLDB.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/migrateSQLDB) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [restoreOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQL) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'
* [restoreSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLDBs) [`Fix`] Fixed error 'Cannot determine the attempt number of the backup run'

## 2023-11-20

* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Fix`] validation failure when no log backups are available
* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Fix`] validation failure when no log backups are available
* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] Improved API call efficiency
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] Improved API call efficiency

## 2023-11-19

* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/windows/restoreFiles) [`New`] restoreFiles for Windows (compiled binary)

## 2023-11-18

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed reportError quiet mode

## 2023-11-17

* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Update`] added broader support for environments (e.g. NAS)
* [legalHoldAll.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHoldAll) [`Update`] added --pushtoreplicas parameter

## 2023-11-16

* [legalHoldAll.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldAll) [`Update`] added -pushToReplicas parameter
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`Update`] added -newerThan parameter

## 2023-11-15

* [replicationQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue) [`Update`] added -newerThan, -olderThan, -ifExpiringBefore selection parameters
* [restoreSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLDBs) [`Update`] added -newerThan parameter
* [sqlJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/sqlJobSelections) [`Fix`] incorrect server-level selection status

## 2023-11-14

* [reverseSizingReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/reverseSizingReport) [`Update`] use more accurate front end size info for VMware VMs
* [heliosAagMonitor](https://github.com/cohesity/community-automation-samples/tree/main/easyScript/heliosAagMonitor) [`New`] EasyScript for monitoring and resolving SQL log chain breaks across Helios clusters

## 2023-11-11

* [sqlRestoreReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/sqlRestoreReport) [`Update`] added support for multi DB restores

## 2023-11-10

* [validateVMBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateVMBackups) [`Fix`] filter non-VM backup from output
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLv2) [`New`] v2 updated script to restore SQL databases

## 2023-11-09

* [heliosUsers.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosUsers) [`New`] report list of Helios users
* [viewGrowth.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/viewGrowth) [`Fix`] fix output file when there's a colon in the vip

## 2023-11-08

* [sqlJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/sqlJobSelections) [`New`] report SQL job selections

## 2023-11-07

* [orgAssignPolicy.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/orgAssignPolicy) [`New`] assign a policy to an organization
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] updated password storage after validation
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] updated password storage after validation

## 2023-11-06

* [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Fix`] Don't clone empty log backups (e.g. passive AAG node)

## 2023-11-05

* [Grafana](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana) [`Update`] added examples for various data source types: PostgreSQL, Prometheus, InfluxDB, JSON API

## 2023-11-03

* [oracleBackupReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleBackupReport) [`Update`] added columns for database type and DataGuard role
* [sqlJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/sqlJobSelections) [`New`] generate report of SQL protection group selections

## 2023-11-02

* [replicationReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/replicationReport) [`Update`] included queued / running replications

## 2023-11-01

* [unprotectVM](https://github.com/cohesity/community-automation-samples/tree/main/linux/unprotectVM) [`New`] compiled binary for linux, unprotect a VM
* [unprotectPhysicalServer](https://github.com/cohesity/community-automation-samples/tree/main/linux/unprotectPhysicalServer) [`New`] compiled binary for linux, unprotect a physical server
* [unprotectSQLServer](https://github.com/cohesity/community-automation-samples/tree/main/linux/unprotectSQLServer) [`New`] compiled binary for linux, unprotect a SQL server
* [unregisterSource](https://github.com/cohesity/community-automation-samples/tree/main/linux/unregisterSource) [`New`] compiled binary for linux, unregister a protection source

## 2023-10-31

* [myBackupStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/myBackupStatus) [`Fix`] fixed PowerShell 5.1 detection issue

## 2023-10-30

* [aagFailoverMinder.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/aagFailoverMinder) [`Update`] added support for helios / multiple clusters

## 2023-10-28

* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added support to specify more than one database (previously was one database or all databases)

## 2023-10-27

* [protectO365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Mailboxes) [`Fix`] Force exclude ID list uniqueness

## 2023-10-26

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] updated auth validation to use basicClusterInfo, fixed copySessionCookie function

## 2023-10-24

* [addObjectToUserAccessList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addObjectToUserAccessList) [`Update`] added -environment parameter to filter on object type

## 2023-10-23

* [instantVolumeMount.py](https://github.com/cohesity/community-automation-samples/tree/main/python/instantVolumeMount) [`Update`] v2 rewrite, modernize authentication, support replicated backups

## 2023-10-22

* [instantVolumeMount.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/instantVolumeMount) [`Update`] v2 rewrite, modernize authentication, support replicated backups

## 2023-10-18

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Update`] added --youngerthan and --olderthan parameters
* [restartFailedJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restartFailedJobs) [`Update`] added --jobname and --joblist parameters
* [pauseProtectionActivity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseProtectionActivity) [`New`] pause or resume protection activities (backup, replication, archive) for maximum restore performance

## 2023-10-17

* [reLicenseCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/reLicenseCluster) [`New`] refresh license for dark site cluster
* [migrateEC2CSMProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateEC2CSMProtectionGroup) [`New`] Migrate EC2 Snapshot Manager protection group from one cluster to another

## 2023-10-16

* [jobDumper.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/jobDumper) [`New`] Dump protection groups and sources to JSON (to aid in development and analysis)
* [jobDumper.py](https://github.com/cohesity/community-automation-samples/tree/main/python/jobDumper) [`New`] Dump protection groups and sources to JSON (to aid in development and analysis)

## 2023-10-13

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Fix`] fixed password prompt for AD user
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed password prompt for AD user
* [deleteObjectBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deleteObjectBackups) [`Update`] moderinized authentication
* [moveProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/moveProtectionGroup) [`Update`] added rename old protection group option

## 2023-10-12

* [recoverVMsV2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMsV2) [`New`] restore multiple VMware VMs using python
* [recoverVMsV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMsV2) [`Update`] added -taskName parameter
* [myBackupStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/myBackupStatus) [`New`] get my current backup status
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] added description field and 2nd output format (custom requested format)
* [chargebackReportV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReportV2) [`Update`] added description field
* [viewStorageReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/viewStorageReport) [`New`] view storage report

## 2023-10-11

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] removed demand minimim powershell version, to support Start-Job
* [expungeDataSpillage.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expungeDataSpillage) [`Update`] no longer connects to replica clusters, run script independently on separate clusters
* [archiveVersionReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveVersionReport) [`New`] reports on the cloud archive version (v1 or v2) in use per protection group
* [pureSnapDiff.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/pureSnapDiff) [`Update`] auto-detect Pure API version

## 2023-10-10

* [deployWindowsAgentSimple.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployWindowsAgentSimple) [`New`] remotely install Cohesity windows agent and set the service account
* [archiveNow-latest.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveNow-latest) [`Update`] modernized authentication
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] use cached data
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] use cached data

## 2023-10-09

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] set last error on cluster not connected to helios
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] clarify password / API key prompts
* [pauseResumeJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseResumeJobs) [`Update`] modernized authentication
* [cancelRunningJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cancelRunningJobs) [`Update`] modernized authentication
* [archiveQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveQueue) [`Update`] modernized authentication

## 2023-10-06

* [activeSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/activeSnapshots) [`Update`] added email support
* [activeSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshots) [`Update`] added email support

## 2023-10-05

* [protectO365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Mailboxes) [`Update`] added include domain filter
* [unprotectedO365Objects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectedO365Objects) [`Update`] added output to CSV
* [featureFlags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/featureFlags) [`Update`] allow import from CSV without timestamp column

## 2023-10-04

* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Update`] added support for wildcard restores e.g. /folder1/*

## 2023-10-03

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Fix`] fixed 'forcePasswordChange' error on AD authentication

## 2023-10-02

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] cosmetic bug 'An item with the same key has already been added. Key: content-type'
* [registerPhysical.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerPhysical) [`Update`] added support for multitenancy
* [chargebackReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReport) [`Fix`] added lower bound startTimeUsecs to query parameters

## 2023-09-29

* [featureFlags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/featureFlags) [`New`] Python script to get, set, export and import feature flags
* [featureFlags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/featureFlags) [`New`] PowerShell script to get, set, export and import feature flags

## 2023-09-28

* [activeSnapshotsRemote.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshotsRemote) [`New`] Script to determine count, oldest, and newest backups available on replica cluster (that can't be queried directly, e.g. isolated vault cluster)
* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] don't show expired archives when using -showFinished

## 2023-09-26

* [reports](https://github.com/cohesity/community-automation-samples/tree/main/reports) [`Update`] Renamed heliosV2 folder to helios and renamed heliosV1 folder to helios-old

## 2023-09-24

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] minor refactoring
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] minor refactoring

## 2023-09-23

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] switched to web session authentication, added support for password reset. email MFA
* [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) [`Update`] switched to web session authentication
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] switched to web session authentication, added support for password reset, email MFA
* [gflagList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflagList) [`Update`] switched to web session authentication
* [gflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflags) [`Update`] switched to web session authentication

## 2023-09-22

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Update`] added option to cancel outdated/all replications per job, per target
* [licenseCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/licenseCluster) [`New`] generates a license from Helios and applies it to a cluster
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added file upload function to support the new licenseCluster script

## 2023-09-21

* [strikeReportV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/strikeReportV2) [`Fix`] bug fix

## 2023-09-19

* [replicationReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/replicationReport) [`Update`] Performance improvement
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] added tenant column
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] added tenant column
* [findFilesV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/findFilesV2) [`New`] New script to search for indexed files

## 2023-09-18

* [oracleLogDeletionDaysReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleLogDeletionDaysReport) [`Fix`] abend on missing database ID

## 2023-09-16

* [unregisterProtectionSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unregisterProtectionSource) [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* [protectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVM) [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* [unprotectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectVM) [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* [migratePhysicalProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migratePhysicalProtectionGroup) [`Update`] added support for multi-tenancy
* [migrateSQLProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateSQLProtectionGroup) [`Update`] added support for multi-tenancy
* [migrateVMProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateVMProtectionGroup) [`Update`] added support for multi-tenancy

## 2023-09-15

* [oracleLogDeletionDaysReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleLogDeletionDaysReport) [`New`] report oracle archive log deletion settings
* [dataReadPerVMReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/dataReadPerVMReport) [`Update`] Improved dataRead adjustment logic

## 2023-09-14

* [strikeReportV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/strikeReportV2) [`Update`] added sourceName column

## 2023-09-13

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] Improved error handling on start
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] Improved error handling on start

## 2023-09-12

* [aagFailoverMinder.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/aagFailoverMinder) [`Fix`] wait for application refresh

## 2023-09-11

* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/heliosV2/powershell/heliosCSVReport) [`New`] script to generate Helios reports in raw CSV format (much faster than heliosReport.ps1)
* [resetMyExpiredPassword.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resetMyExpiredPassword) [`New`] script to reset my expired password

## 2023-09-08

* [protectGPFS.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectGPFS) [`New`] python script to protect GPFS Filesets (agent-based approach)

## 2023-09-07

* [pauseResumeJobs.py.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseResumeJobs.py) [`Update`] added show mode
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added --noalert option
* [refreshSource.py](https://github.com/cohesity/community-automation-samples/tree/main/python/refreshSource) [`Fix`] wait for app/DB refresh
* [aix](https://github.com/cohesity/community-automation-samples/tree/main/aix) [`Update`] Added MFA support to compiled binaries for AIX
* [linux](https://github.com/cohesity/community-automation-samples/tree/main/linux) [`Update`] Added MFA support to compiled binaries for Linux
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] Added MFA support
* [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) [`Update`] Added MFA support
* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Update`] Added MFA support

## 2023-09-06

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added timeout parameter to apiauth and api functions (required for latest version of backupNow.py)
* [cancelArchivesV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelArchivesV2) [`Update`] added support to filter on target name
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Fix`] fixed edge case bug that caused unhandled exception
* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] performance improvements
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] performance improvements

## 2023-09-04

* [gflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflags) [`Fix`] Fixed service restart function

## 2023-09-03

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] performance improvements
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] performance improvements

## 2023-08-31

* [recoverHyperVVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverHyperVVMs) [`Update`] added support for restore to stand alone failover clusters and stand alone hosts

## 2023-08-30

* [unprotectCcsM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365Mailboxes) [`Update`] added support for mailbox selection by UUID
* [storagePerVMReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerVMReport) [`New`] new script to report storage consumed per VMware VM
* [instantVolumeMount.py](https://github.com/cohesity/community-automation-samples/tree/main/python/instantVolumeMount) [`Update`] added support for v2 runid format
* [updateJobSettings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateJobSettings) [`New`] New script to update common protection group settings

## 2023-08-28

* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added additional parameters
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added offending line number to cohesity-api-debug.log

## 2023-08-27

* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] added exit 0 when no active archive tasks found, exit 1 if tasks are found
* [aagFailoverMinder.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/aagFailoverMinder) [`Fix`] updated run payload to remove kLocal copyRun
* [updateAWSCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateAWSCredentials) [`New`] new python script to update access key / secret key for AWS source.

## 2023-08-22

* [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) [`Update`] added modern authentication support
* [registerOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/registerOracle) [`Fix`] fixed error that occured when no Oracle sources were present on the cluster

## 2023-08-19

* [addObjectToUserAccessList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/addObjectToUserAccessList) [`Update`] added support for AD groups

## 2023-08-17

* [updateGCPExternalTargetPrivateKey.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateGCPExternalTargetPrivateKey) [`New`] PowerShell script to update the private key on a Google Cloud archive target
* [expireOldSnaps.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnaps) [`Update`] added modern authentication methods (API keys, MFA, Helios, etc)
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] added estimated archival usage per object
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] added estimated archival usage per object
* [activeSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/activeSnapshots) [`Update`] added support for multitenancy
* [updateJobDescriptions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJobDescriptions) [`New`] PowerShell script to update protection group descriptions from a CSV file

## 2023-08-16

* [restoreReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreReport) [`Update`] added recoery point to output
* [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQL) [`Fix`] Fixed cosmetic error "Cannot index into a null array" when checking previous restores during resume recovery

## 2023-08-15

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] Enforce TLSv1.2 to solve TLSv1.3 handshake failures with PowerShell.Core on Windows Server 2022

## 2023-08-14

* [strikeReportV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/strikeReportV2) [`Fix`] parsing misbehavior on Windows PowerShell 5.1
* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Fix`] updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED"
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Fix`] updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED"

## 2023-08-12

* [updateArchiveRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateArchiveRetention) [`Fix`] fixed filter by policy names
* [usersAndGroups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/usersAndGroups) [`New`] report list of users and groups

## 2023-08-11

* [backedUpFileList](https://github.com/cohesity/community-automation-samples/tree/main/linux/backedUpFileList) [`New`] compiled binary version of backedUpFileList for Linux
* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/linux/restoreFiles) [`New`] compiled binary version of restoreFiles for Linux
* [gflagList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/gflagList) [`New`] get complete list of gflags for a service
* [unprotectCcsM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365Mailboxes) [`New`] unprotect M365 mailboxes in CCS

## 2023-08-10

* [clusterProtectedObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectedObjects) [`New`] cluster-direct API script to generate protected objects report
* [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Fix`] performance improvement

## 2023-08-09

* [expireOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots) [`Update`] added -s, --skipmonthlies parameter
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] updated storage calculations

## 2023-08-02

* [protectedFilePathReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedFilePathReport) [`Update`] added output column for skipNestedVolumes

## 2023-08-01

* [protectO365OneDrive.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365OneDrive) [`Update`] added support for UUIDs as input list of users to protect
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] added recent growth column to the output

## 2023-07-31

* [protectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVM) [`Fix`] fixed disk exclusions
* [protectMongoDB.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectMongoDB) [`Update`] exit with 0 on no databases to protect

## 2023-07-30

* [protectWindows.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectWindows) [`Fix`] remove null entry from exclude paths
* [globalExcludePaths.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/globalExcludePaths) [`Fix`] remove null entry from exclude paths

## 2023-07-29

* [epic_pure_freeze_thaw](https://github.com/cohesity/community-automation-samples/tree/main/bash/epic_pure_freeze_thaw) [`Update`] parameterized configuration variables and added autodetection of OS (Linux or AIX)

## 2023-07-27

* [addGlobalExcludePaths.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addGlobalExcludePaths) [`Fix`] remove null entry from exclude paths
* [cancelCcsProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/cancelCcsProtectionRuns) [`Update`] added -subType filter (e.g. kO365Sharepoint)
* [protectCcsM365Groups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Groups) [`Update`] updated to support autoselect of groups with non-unique names
* [protectCcsM365Teams.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Teams) [`Update`] updated to support autoselect of teams with non-unique names
* [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Update`] updated to support autoselect of sites with non-unique names
* [protectLinux.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux) [`Fix`] remove null entry from exclude paths
* [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Fix`] cluster/host not found error due to unexpected sorting in object hierarchy
* [viewDR.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) [`Update`] replicateViews.ps1 and added replication completion check to cleanupJobs.ps1

## 2023-07-26

* [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQL) [`Fix`] Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* [restoreSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/restoreSQLDBs) [`Fix`] Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Fix`] Updated resource pool search to provide clearer error message when compute resource not found.

## 2023-07-20

* [backedUpFileList](https://github.com/cohesity/community-automation-samples/tree/main/aix/backedUpFileList) [`New`] backedUpFileList for AIX

## 2023-07-19

* [restoreFiles](https://github.com/cohesity/community-automation-samples/tree/main/aix/restoreFiles) [`New`] restoreFiles for AIX
* [backupNow](https://github.com/cohesity/community-automation-samples/tree/main/aix/backupNow) [`Fix`] backupNow for AIX fix for 6.8.1 P11 / 6.6.0 P34 error: "TARGET_NOT_IN_POLICY_NOT_ALLOWED%!(EXTRA int64=0)"
