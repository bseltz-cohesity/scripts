# Change Log for cohesity/community-automation-samples

* [`2025-12-04`] [emptyVMProtectionGroups.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/emptyVMProtectionGroups) [`New`] Report VM PRotection Groups that backed up zero VMs
* [`2025-12-03`] [protectCcsM365Groups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Groups) [`Update`] added ability to protect groups by SMTP address
* [`2025-12-03`] [supportUserPassword.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/supportUserPassword) [`Update`] added ability to manage other users
* [`2025-11-26`] [registerSQLVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/registerSQLVM) [`Update`] modernized authentication
* [`2025-11-26`] [missingCcsObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/missingCcsObjects) [`New`] Unprotect missing CCS objects
* [`2025-11-25`] [restoreEC2VM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreEC2VM) [`Update`] added support for NGCE
* [`2025-11-20`] [protectSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/protectSQL) [`Update`] added -aagBackupPreference option
* [`2025-11-20`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] fixed CCS region ID bug
* [`2025-11-19`] [registerOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/registerOracle) [`Update`] added -o, --oraclecluster option
* [`2025-11-07`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] fix for expired log backups
* [`2025-11-06`] [legalHoldAll.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHoldAll) [`Update`] fix for no copyRuns
* [`2025-11-03`] [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Update`] added -objectName and -objectUuid filter parameters
* [`2025-11-03`] [heliosObjectUuid.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/heliosObjectUuid) [`New`] Lookup global Uuid of an object in Helios
* [`2025-10-27`] [legalHoldCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/legalHoldCCS) [`Update`] added -startDate and -endDate parameters
* [`2025-10-22`] [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] fixed issue with multiple protection groups
* [`2025-10-21`] [recoveryStatsReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/recoveryStatsReport) [`Update`] added multi-tenancy support
* [`2025-10-20`] [cloneVMProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVMProtectionGroup) [`Update`] re-published script
* [`2025-10-17`] [smbFileOpens.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/smbFileOpens) [`Update`] added -smbUsername and -matchPath parameters
* [`2025-10-16`] [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Update`] optimized search query
* [`2025-10-15`] [clusterDiskReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterDiskReport) [`New`] generate a cluster disk report
* [`2025-10-08`] [legalHoldObject.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldObject) [`Update`] implemented wildcards
* [`2025-10-08`] [restoreCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreCassandra) [`Update`] added new -dc (--datacenters) option
* [`2025-10-07`] [migrateOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/migrateOracle) [`New`] migrate an instantly restored Oracle database that was not migrated yet
* [`2025-10-04`] [objectProtectionStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/objectProtectionStatus) [`Update`] modernized authentication and optimized API calls
* [`2025-10-02`] [smbFileClose.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbFileClose) [`Update`] improved filter options and implemented paging
* [`2025-09-30`] [objectProtectionStatus.py](https://github.com/cohesity/community-automation-samples/tree/main/python/objectProtectionStatus) [`Update`] modernized authentication and optimized API calls
* [`2025-09-30`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] fixed updatepw behavior
* [`2025-09-26`] [expungeDataSpillage.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expungeDataSpillage) [`Update`] added support for NAS external targets
* [`2025-09-24`] [replicateOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots) [`Update`] fixed resync bug
* [`2025-09-23`] [pulseLogs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/pulseLogs) [`Update`] modernized authentication
* [`2025-09-19`] [protectionGroupScheduleReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectionGroupScheduleReport) [`Update`] modernized authentication
* [`2025-09-19`] [recoveryPoints.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/recoveryPoints) [`Update`] fixed crash on unfinished protection run
* [`2025-09-16`] [heliosSlaMonitor.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosSlaMonitor) [`Update`] added max run time option
* [`2025-09-15`] [uploadSSLCert.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/uploadSSLCert) [`Update`] added bridge restart option
* [`2025-09-15`] [chargebackReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReport) [`Update`] fixed missing data column
* [`2025-09-10`] [clusterInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterInfo) [`Update`] fix for 7.x
* [`2025-09-04`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added org suppport for Helios
* [`2025-09-03`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added org suppport for Helios
* [`2025-09-03`] [protectVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectVMs) [`Update`] added support for VMs with non-unique names
* [`2025-09-02`] [clusterInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterInfo) [`Update`] [`Update`] added support for 7.x
* [`2025-09-02`] [clusterInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterInfo) [`Update`] added support for 7.x
* [`2025-08-31`] [protectLinuxVolumes.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinuxVolumes) [`New`] protect physical linux servers (block-based)
* [`2025-08-31`] [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added support for different number of channels per RAC node
* [`2025-08-30`] [downloadCcsM365MailboxPST.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/downloadCcsM365MailboxPST) [`New`] Download M365 Mailboxes as PST (from CCS)
* [`2025-08-22`] [remoteAdapterExample.sh](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/remoteAdapterExample) [`New`] basic remote adapter example
* [`2025-08-22`] [protectLinux.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux) [`Update`] added parameters to enable/disable Cache optimization
* [`2025-08-22`] [protectLinux.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux) [`Update`] added parameters to enable/disable Cache optimization
* [`2025-08-20`] [onboardSSOUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/onboardSSOUser) [`New`] add SSO users to Cohesity access management
* [`2025-08-14`] [onboardADUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/onboardADUser) [`New`] Onboard Active Directory Users and Groups using PowerShell
* [`2025-08-14`] [protectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVM) [`Update`] added -vmMatch parameter
* [`2025-08-14`] [migrateDirectoryQuotas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateDirectoryQuotas) [`New`] migrate directory quotas from one view to another
* [`2025-08-14`] [migrateView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateView) [`Update`] added migration of directory quotas
* [`2025-08-12`] [resolveAlerts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resolveAlerts) [`Update`] added -alertId parameter
* [`2025-08-11`] [policyTool7.py](https://github.com/cohesity/community-automation-samples/tree/main/python/policyTool) [`Fix`] fixed issue adding multiple archival frequencies
* [`2025-08-11`] [latestSQLRecoveryPoint.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/latestSQLRecoveryPoint) [`Update`] modernized authentication
* [`2025-08-11`] [sqlRecoveryPoints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlRecoveryPoints) [`Update`] modernized authentication
* [`2025-08-05`] [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added db credentials parameters
* [`2025-08-04`] [protectedObjectInventory.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/protectedObjectInventory) [`Update`] bug fixes
* [`2025-07-27`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] fixed reaction to bad password
* [`2025-07-25`] [clusterProtectionRunsNGCE.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns) [`New`] report variant for NGCE
* [`2025-07-25`] [oracleBackupReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleBackupReport) [`Update`] added support for NGCE
* [`2025-07-21`] [shareList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/shareList) [`New`] list views and shares
* [`2025-07-18`] [ipmiPassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/ipmiPassword) [`New`] set IPMI password
* [`2025-07-17`] [objectRunHistory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectRunHistory) [`New`] Query the run history of an object
* [`2025-07-17`] [backedUpFileListJSON.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileListJSON) [`New`] variant of backedUpFileList that outputs JSON to stdout
* [`2025-07-17`] [restoreVMFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreVMFiles) [`Update`] added support for AHV
* [`2025-07-17`] [downloadLatestWarnings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadLatestWarnings) [`Update`] removed spaces from output file name
* [`2025-07-15`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] fixed error reporting issue
* [`2025-07-15`] [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] increased timeout for external target stats
* [`2025-07-11`] [smbViewList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbViewList) [`Update`] fixed output format
* [`2025-07-11`] [agentSummaryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentSummaryReport) [`Update`] added agent port column
* [`2025-07-09`] [legalHoldCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/legalHoldCCS) [`New`] add/remove legal hold on M365 mailboxes, onedrives in CCS
* [`2025-07-08`] [downloadLatestWarnings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadLatestWarnings) [`New`] download backup error logs
* [`2025-07-07`] [protectAHVVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectAHVVMs) [`New`] Protect AHV VMs
* [`2025-06-30`] [protectAHVVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectAHVVMs) [`Update`] updated to v2 API and added disk exclusions
* [`2025-06-30`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added report cohesity-api version to log
* [`2025-06-29`] [autoprotectO365.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/autoprotectO365) [`Update`] added guardrails
* [`2025-06-26`] [pauseResumeJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseResumeJobs) [`Update`] added output folder parameter
* [`2025-06-26`] [changeArchiveRetention.py](https://github.com/cohesity/community-automation-samples/tree/main/python/changeArchiveRetention) [`Update`] added external target name parameter
* [`2025-06-24`] [agentVersions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentVersions) [`Update`] added CBT status columns
* [`2025-06-20`] [recoverAHVVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs) [`Update`] added -recoveryType option
* [`2025-06-20`] [recoverAHVVMs-throttled.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs-throttled) [`Update`] added -recoveryType option
* [`2025-06-20`] [refreshSourceCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/refreshSourceCcs) [`New`] refresh registered sources in CCS
* [`2025-06-18`] [sqlRestoreReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlRestoreReport) [`Update`] minor bug fix
* [`2025-06-17`] [protectCcsWindows.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsWindows) [`New`] protect physical Windows servers in CCS
* [`2025-06-16`] [pgInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pgInfo) [`New`] didplay Postgres connection info
* [`2025-06-16`] [restoreVMFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreVMFiles) [`Update`] added job name filter
* [`2025-06-16`] [restoreVMFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreVMFiles) [`Update`] added job name filter
* [`2025-06-15`] [replicateOldSnapshotsV2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshotsV2) [`Update`] added filter options
* [`2025-06-15`] [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) [`Update`] added filter options
* [`2025-06-12`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] authentication flow fixes
* [`2025-06-12`] [restoreCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreCassandra) [`Update`] updated target server lookup
* [`2025-06-11`] [cloneSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/cloneSQLDBs) [`Update`] fixed log lookup
* [`2025-06-10`] [firewallTool.py](https://github.com/cohesity/community-automation-samples/tree/main/python/firewallTool) [`Update`] improved list function
* [`2025-06-10`] [unprotectMailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMailboxes) [`Update`] modernized
* [`2025-06-10`] [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] added column for AWS Tags
* [`2025-06-10`] [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] added column for AWS Tags
* [`2025-06-10`] [firewallTool.py](https://github.com/cohesity/community-automation-samples/tree/main/python/firewallTool) [`Update`] improved list function
* [`2025-06-10`] [firewallTool.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/firewallTool) [`Update`] improved list function
* [`2025-06-08`] [storePasswordInFile.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/storePasswordInFile) [`Update`] added password validation
* [`2025-06-03`] [epic_nimble_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/epic_nimble_freeze_thaw) [`New`] Example Epic freeze thaw script
* [`2025-05-28`] [restorePhysicalFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restorePhysicalFiles) [`New`] simplified restore files for physical servers
* [`2025-05-23`] [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] updated to export external target stats for debugging
* [`2025-05-22`] [replicateViews.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) [`Update`] updated to double test for protection groups to run
* [`2025-05-22`] [physicalBackupPathsHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsHistoryReport) [`Update`] added helios connection resliency
* [`2025-05-20`] [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] handle new existing run error verbiage
* [`2025-05-20`] [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] handle new existing run error verbiage
* [`2025-05-19`] [unprotectPhysicalServer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectPhysicalServer) [`Update`] added support for filtering by application
* [`2025-05-19`] [agentVersions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentVersions) [`Update`] added environment filter
* [`2025-05-19`] [agentVersions.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/agentVersions) [`Update`] added environment filter
* [`2025-05-15`] [storageReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storageReport) [`Update`] added support for Helios authentication
* [`2025-05-14`] [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] fixed divide by zero
* [`2025-05-13`] [epicAzureFreezeThawRole.json](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/epic_azure_freeze_thaw) [`New`] Added custom role creation JSON
* [`2025-05-13`] [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Update`] fixed snapshot count bug
* [`2025-05-13`] [archiveOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/archiveOldSnapshots) [`Update`] added auto retention option
* [`2025-05-13`] [registeredSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/registeredSources) [`Update`] added unhealthy switch and email options
* [`2025-05-12`] [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Update`] added ccsonly parameter
* [`2025-05-12`] [protectCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectCassandra) [`Update`] added qospolicy parameter
* [`2025-05-09`] [oracleProtectionStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/oracleProtectionStatus) [`Update`] added exclude parameters
* [`2025-05-07`] [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Update`] fixed folder lookup
* [`2025-05-06`] [refreshSource.py](https://github.com/cohesity/community-automation-samples/tree/main/python/refreshSource) [`Update`] improved API query
* [`2025-05-06`] [refreshSource](https://github.com/cohesity/community-automation-samples/tree/main/linux/refreshSource) [`Update`] improved API query
* [`2025-05-06`] [copyAlertRules.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copyAlertRules) [`New`] Copy the alert notification rules from one cluster to another
* [`2025-05-06`] [prometheusClusterStatsExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/Prometheus/ClusterStats) [`Update`] added suport for Helios authentication
* [`2025-05-03`] [epic_azure_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/epic_azure_freeze_thaw) [`New`] freeze/thaw Iris DB in Azure VM
* [`2025-05-02`] [selfServiceSnapshotConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/selfServiceSnapshotConfig) [`Update`] added support for allow/deny lists for SMB views
* [`2025-05-01`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] auth flow fixes
* [`2025-04-30`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] minor error reporting fixes
* [`2025-04-29`] [supportUserPassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/supportUserPassword) [`New`] set/update support user password
* [`2025-04-29`] [supportUserPassword.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/supportUserPassword) [`New`] set/update support user password
* [`2025-04-28`] [updateLocalUserPassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateLocalUserPassword) [`Update`] added support for user to change their own password
* [`2025-04-28`] [replicationWireStats.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/replicationWireStats) [`Update`] enforce 30 day maximum
* [`2025-04-28`] [expireOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapshots) [`Update`] concolidated multiple scripts
* [`2025-04-25`] [protectedVMsWithExcludedDisks.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectedVMsWithExcludedDisks) [`Update`] modernized authentication
* [`2025-04-25`] [registeredSources.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/registeredSources) [`Update`] modernized authentication
* [`2025-04-25`] [cassandraProtectionReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/cassandraProtectionReport) [`New`] generate cassandra protection report
* [`2025-04-25`] [cassandraProtectionReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/cassandraProtectionReport) [`New`] generate cassandra protection report
* [`2025-04-24`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] authentication flow fixes
* [`2025-04-21`] [moveProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/moveProtectionGroup) [`Update`] disabled positional binding
* [`2025-04-21`] [jobRunsReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/jobRunsReport) [`Update`] modernized authentication
* [`2025-04-21`] [protectedObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/protectedObjectReport) [`Update`] modernized authentication
* [`2025-04-14`] [storageGrowth.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageGrowth) [`Update`] added multi-cluster support
* [`2025-04-13`] [restoreSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLDBs) [`Update`] added support for multiple log file paths
* [`2025-04-13`] [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQL) [`Update`] added support for multiple log file paths
* [`2025-04-13`] [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] added support for multiple log file paths
* [`2025-04-13`] [resolveAlerts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resolveAlerts) [`Update`] various improvements and fixes
* [`2025-04-11`] [refreshSource](https://github.com/cohesity/community-automation-samples/tree/main/linux/refreshSource) [`New`] packaged version for Linux
* [`2025-04-10`] [protectedFilePathReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedFilePathReport) [`Update`] added directive file support
* [`2025-04-10`] [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] fixed diff options
* [`2025-04-09`] [storageReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storageReport) [`Update`] added multi-cluster support
* [`2025-04-08`] [policyTool.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/policyTool) [`Update`] added support for continuous data protection
* [`2025-04-08`] [policyTool7.py](https://github.com/cohesity/community-automation-samples/tree/main/python/policyTool) [`Update`] added support for continuous data protection
* [`2025-04-08`] [policyTool.py](https://github.com/cohesity/community-automation-samples/tree/main/python/policyTool) [`Update`] added support for continuous data protection
* [`2025-04-07`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] fixed search query
* [`2025-04-05`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] minor auth flow updates
* [`2025-04-04`] [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Update`] fixed date format
* [`2025-04-03`] [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] solved missing tenant source name issue
* [`2025-04-03`] [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] solved missing tenant source name issue
* [`2025-04-03`] [restoreCcsVMWareVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreCcsVMWareVM) [`New`] Restore VMWare VMs from CCS
* [`2025-04-03`] [cert.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cert) [`Update`] bug fix
* [`2025-04-02`] [smbPermissions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbPermissions) [`Update`] added support to add and remove super users
* [`2025-04-02`] [recoverWindowsShareAsView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverWindowsShareAsView) [`Update`] added support to add super users
* [`2025-04-01`] [resolveAlerts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resolveAlerts) [`Update`] use existing resolution if it exists
* [`2025-04-01`] [objectSummaryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/objectSummaryReport) [`Update`] updated environment types
* [`2025-03-31`] [registerOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/registerOracle) [`Update`] bug fix
* [`2025-03-31`] [validateServerBackup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateServerBackup) [`Update`] added volume types for Hyper-V
* [`2025-03-28`] [recoverWindowsShareAsView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverWindowsShareAsView) [`New`] recover a Windows share as a Cohesity View
* [`2025-03-28`] [migrateWindowsShares.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateWindowsShares) [`Update`] modernized authentication
* [`2025-03-27`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] fixed null error return
* [`2025-03-27`] [registerCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerCassandra) [`Update`] added ability to update existing source
* [`2025-03-26`] [activeSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/activeSnapshots) [`Update`] added -shortOnly option
* [`2025-03-21`] [deploySaaSConnector.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/deploySaaSConnector) [`Update`] added support for VMC API Token
* [`2025-03-21`] [cloneOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracle) [`Update`] bug fix
* [`2025-03-20`] [archiveMediaInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveMediaInfo) [`Update`] added object level reporting
* [`2025-03-20`] [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) [`Update`] renamed resync option
* [`2025-03-20`] [replicateOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots) [`Update`] renamed resync option
* [`2025-03-18`] [restoreCcsM365Calendar.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreCcsM365Calendar) [`Update`]
* [`2025-03-18`] [unprotectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365Sites) [`Update`]
* [`2025-03-18`] [clusterStorageStats.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterStorageStats) [`Update`] modernized authentication
* [`2025-03-17`] [archiveMediaInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/archiveMediaInfo) [`Update`] improved runs loop
* [`2025-03-17`] [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] catch null runs response
* [`2025-03-16`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added retries for retryable errors
* [`2025-03-16`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added retries for retryable errors
* [`2025-03-14`] [protectCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectCassandra) [`Update`] added datacenter selection and other fixes
* [`2025-03-13`] [vm_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/vm_freeze_thaw) [`New`] Remote adapter script to quiesce an application in a VM
* [`2025-03-13`] [jobRunning](https://github.com/cohesity/community-automation-samples/tree/main/linux/jobRunning) [`New`] check if job is running (packaged for Linux)
* [`2025-03-13`] [backupNow](https://github.com/cohesity/community-automation-samples/tree/main/linux/backupNow) [`Update`] (packaged for Linux) sync with python version
* [`2025-03-13`] [registerCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerCassandra) [`Update`] added support for SSH private key authentication
* [`2025-03-12`] [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Update`] added legal hold status column
* [`2025-03-12`] [legalHoldObject.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldObject) [`Update`]
* [`2025-03-11`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`]
* [`2025-03-10`] [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] improved runs query
* [`2025-03-10`] [deployVE.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployVE) [`Update`] fixed password reset
* [`2025-03-10`] [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Update`] fix for sites with sub-sites
* [`2025-03-08`] [selfServiceSnapshotConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/selfServiceSnapshotConfig) [`New`] Configure Snapshot Self-Service on Cohesity Views
* [`2025-03-07`] [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`]
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
* [`2025-02-25`] [copySecurityConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/copySecurityConfig) [`New`] copy account security configuration from one cluster to another
* [`2025-02-14`] [maintenance.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/maintenance) [`New`] set maintenance mode on protection sources
* [`2025-02-11`] [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] improved API queries
* [`2025-02-11`] [restoreFilesReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/restoreFilesReport) [`Update`] updated column headings
* [`2025-02-11`] [restoreFilesReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreFilesReport) [`Update`] modernized authentication and updated column headings
* [`2025-02-10`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] improved API queries
* [`2025-02-10`] [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) [`Update`] added VM recovery point
* [`2025-02-09`] [recoverNASVolume.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverNASVolume) [`Update`] updated to v2 API and added SMB share permissions and subnet allow list controls
* [`2025-02-09`] [recoverNASVolume.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverNASVolume) [`Update`] added recover as View and SMB share permissions and subnet allow list controls
* [`2025-02-08`] [registerGenericNas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerGenericNas) [`Update`] modernized authentication
* [`2025-02-08`] [registerGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerGenericNas) [`Update`] modernized authentication
* [`2025-02-08`] [protectGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectGenericNas) [`Update`] modernized authentication
* [`2025-02-07`] [registerDB2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerDB2) [`New`] register DB2 UDA protection source
* [`2025-02-06`] [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] added support for multiple datastores
* [`2025-02-06`] [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added support for multiple datastores
* [`2025-02-05`] [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) [`Fix`] added pagination to file search
* [`2025-02-05`] [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Fix`] added pagination to file search
* [`2025-02-04`] [sqlProtectedObjectReport](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlProtectedObjectReport) [`Update`] improved protectionSources query performance
* [`2025-02-03`] [protectionRunsReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectionRunsReport) [`Update`] added job ID to output
* [`2025-02-02`] [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] modernized authentication
* [`2025-02-02`] [backedUpFSReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backedUpFSReport) [`Update`] modernized authentication
* [`2025-02-02`] [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileFiles) [`Update`] modernized authentication
* [`2025-01-31`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed /v2/users/session authentication
* [`2025-01-30`] [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) [`New`] report on VM recoveries
* [`2025-01-27`] [updateCcsRdsCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [`2025-01-27`] [updateCcsRdsCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [`2025-01-27`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added region parameter to api function
* [`2025-01-23`] [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) [`Update`] Added CSV output and total folder size
* [`2025-01-23`] [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Update`] Added CSV output and total folder size
* [`2025-01-17`] [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added -coe, --continueonerror option, -w, --wait option, updated folder enumeration
* [`2025-01-16`] [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added -env, --environment, -on, --objectname, -ol, --objectlist pre-filtering parameters
* [`2025-01-15`] [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added overwrite handaling
* [`2025-01-14`] [vmRecoveryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/vmRecoveryReport) [`New`] report on VM recoveries
* [`2025-01-14`] [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Fix`] fixed issue with nested sites
* [`2025-01-13`] [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/heliosV2/powershell/heliosCSVReport) [`Update`] added filters functionality
* [`2025-01-10`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added `Get-Runs` function
* [`2025-01-10`] [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] updated to use the Get-Runs function
* [`2025-01-10`] [runningJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/runningJobs) [`Update`] updated to use the Get-Runs function
* [`2025-01-10`] [maintenance.py](https://github.com/cohesity/community-automation-samples/tree/main/python/maintenance) [`New`] set maintenance mode on protection sources
* [`2025-01-08`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added getRuns function
* [`2025-01-07`] [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) [`Fix`] solved paging issue
* [`2025-01-07`] [fixRedundantProtection.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fixRedndantProtection) [`Update`] added filtering for M365
* [`2025-01-07`] [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added --noalert option
* [`2025-01-02`] [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] added `-backupType` parameter

## Old Change Logs

* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2023.md)
