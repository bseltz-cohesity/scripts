# Change Log for cohesity/community-automation-samples

## 2024-10-23

* [reverseSizingReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/reverseSizingReport) [`Fix`] fix for Cohesity version 7
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] added garbage stats
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] added garbage stats

## 2024-10-22

* [pauseResumeJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/pauseResumeJobs) [`Update`] modernized authentication
* [unprotectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365Sites) [`New`] unprotect M365 Sites from CCS

## 2024-10-21

* [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`Update`] added better masking for dir op file names
* [lastRunStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/lastRunStatus) [`Update`] modernized authentication
* [protectOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/protectOracle) [`Update`] added support for instant log deletion
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added support for instant log deletion

## 2024-10-17

* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] include cluster software version in output
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] include cluster software version in output
* [chargebackReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReport) [`Update`] modernized authentication
* [chargebackReportV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/chargebackReportV2) [`Update`] modernized authentication

## 2024-10-15

* [isilon-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilon-api) [`Fix`] fixed authentication on PowerShell 5.1
* [datalockSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/datalockSnapshots) [`Fix`] updated to work with modern Cohesity versions

## 2024-10-14

* [addLocalUser.py](https://github.com/cohesity/community-automation-samples/tree/main/python/addLocalUser) [`New`] add local Cohesity user
* [archiveOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveOldSnapshots) [`Fix`] date format bug
* [archiveNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveNow) [`Update`] made -keepFor optional
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed PowerShell Core date formatting issue

## 2024-10-11

* [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Update`] added -objectMatch parameter
* [cancelRunningJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelRunningJob) [`Update`] modernized authentication

## 2024-10-10

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Fix`] fixed systax error
* [clusterProtectionRuns.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns) [`Update`] added support for Helios authenticatioon

## 2024-10-09

* [vssSnapshot](https://github.com/cohesity/community-automation-samples/tree/main/windows/vssSnapshot) [`New`] Pre and Post scripts to create VSS snapshots for physical file-based protection groups

## 2024-10-08

* [heliosAsyncCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosAsyncCSVReport) [`New`] async reporting script
* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Update`] scalability improvements
* [deployCCSWindowsAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/deployCCSWindowsAgent) [`Update`] set default install to agaent only (no CBT drivers)

## 2024-10-07

* [jobFailures.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/jobFailures) [`Update`] added support for Helios authentication
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Fix`] catch DB not found errors

## 2024-10-05

* [clusterInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterInfo) [`Update`] added support for Helios authentication

## 2024-10-04

* [protectLinux.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux) [`Fix`] removed deprecated properties
* [protectLinux.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux) [`Fix`] removed deprecated properties

## 2024-10-03

* [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Update`] added support for multiple VMs
* [clusterProtectionRuns.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns) [`Update`] added output file/path parameters, object name filters, tag column

## 2024-10-02

* [updateLocalUserPassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateLocalUserPassword) [`New`] update a local user's password
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Fix`] handle bookkeeper stats error

## 2024-10-01

* [recoveryPoints.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/recoveryPoints) [`Update`] added support for Helios authentication
* [protectOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/protectOracle) [`Fix`] fixed Rack node selection and added -deleteoghours parameter
* [clusterInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterInfo) [`Fix`] removed legacy code

## 2024-09-30

* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Fix`] fixed Rack node selection and added -deleteoghours parameter
* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Fix`] fixed restore from archive issue

## 2024-09-25

* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Fix`] fixed time range issue
* [protectO365Mailboxes](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Mailboxes) [`Update`] added -clear and -reprotect options

## 2024-09-23

* [replicateOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicateOldSnapshots) [`Fix`] Fixed incorrect expiration date

## 2024-09-20

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] allow PUT/POST requests to Read-only Helios clusters for advanced queries
* [heliosAnomalyFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosAnomalyFileList) [`Fix`] fixed snapshot selection issue

## 2024-09-19

* [replicateOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshots) [`Update`] updated to use V2 API
* [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`Update`] added masking for dir op file names

## 2024-09-18

* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) [`Update`] added -timeoutSeconds parameter

## 2024-09-13

* [clusterNumberOfProtectedVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterNumberOfProtectedVMs) [`Update`] added support for Azure and AWS VMs

## 2024-09-12

* [throttleReplication.py](https://github.com/cohesity/community-automation-samples/tree/main/python/throttleReplication) [`Update`] added support for updated credentials

## 2024-09-11

* [cancelArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelArchives) [`Update`] added logs only option
* [consumptionTrend.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/consumptionTrend) [`Update`] modernized authentication
* [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] added support for Oracle and UDA
* [cloneBackupToView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cloneBackupToView) [`Update`] added support for Oracle and UDA

## 2024-09-10

* [deleteView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deleteView) [`Update`] modernized authentication
* [deleteView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deleteView) [`New`] delete a Cohesity view
* [listViews.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/listViews) [`New`] List Cohesity views

## 2024-09-09

* [createViewAlias.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createViewAlias) [`Update`] modernized authentication
* [createS3View.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createS3View) [`Update`] modernized authentication
* [createSMBView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createSMBView) [`Update`] modernized authentication
* [createViewAlias.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createViewAlias) [`Update`] modernized authentication
* [createS3View.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createS3View) [`Update`] modernized authentication
* [createSMBView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createSMBView) [`Update`] modernized authentication
* [createNfsView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createNfsView) [`Update`] modernized authentication

## 2024-09-08

* [protectRemoteAdapter.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectRemoteAdapter) [`Update`] modernized authentication and refactored

## 2024-09-07

* [protectRemoteAdapter.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectRemoteAdapter) [`New`] Create or update a remote adapter protection group

## 2024-09-06

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] added support for Ft Knox
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] added support for Ft Knox
* [cloneSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/cloneSQL) [`Fix`] Fixed exit codes to return non-zero for all unsuccessful outcomes

## 2024-09-04

* [updateJobSettings](https://github.com/cohesity/community-automation-samples/tree/main/python/updateJobSettings) [`Update`] added controls for indexing paths
* [updateJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJob) [`Update`] added controls for indexing paths

## 2024-09-02

* [uploadSSLCert.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/uploadSSLCert) [`Update`] modernized authentication

## 2024-08-31

* [protectCcsEC2VMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCCSEC2VMs) [`Update`] added parameters to include VMs by tag and to exclude disks
* [protectCCSEC2VMs.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/protectCCSEC2VMs) [`Update`] added parameters to include VMs by tag and to exclude disks

## 2024-08-29

* [updateJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJob) [`Update`] added enableIndexing/disableIndexing

## 2024-08-28

* [expireOldSnapshots.py](https://github.com/cohesity/community-automation-samples/tree/main/python/expireOldSnapshots) [`Update`] added active replication confirmation
* [agentVersions.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/agentVersions) [`Fix`] solved crash on missing agent/version

## 2024-08-26

* [aagFailoverMonitor.py](https://github.com/cohesity/community-automation-samples/tree/main/python/aagFailoverMonitor) [`New`] Resolve SQL Log Chain Breaks and AAG Failovers
* [validateServerBackup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateServerBackup) [`Fix`] updated to solve missing attemptNum property
* [updateCcsSqlStreams.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/updateCcsSqlStreams) [`New`] update stream count for CCS SQL backups

## 2024-08-20

* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added outputfile parameter
* [pgdumpBackup](https://github.com/bseltz-cohesity/scripts/tree/master/remoteAdapter/pgdumpBackup) [`New`] Remote adapter script to backup PostgreSQL

## 2024-08-19

* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Fix`] end and start dates not honored

## 2024-08-16

* [registerPhysical.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerPhysical) [`Update`] added -r, --reregister option
* [registerPhysical.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerPhysical) [`Update`] added -reRegister option

## 2024-08-14

* [jobList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/jobList) [`Update`] modernized authentication
* [rsyncBackup](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/rsyncBackup) [`New`] Remote Adapter Rsync backup script and instructions
* [lv_snapper](https://github.com/cohesity/community-automation-samples/tree/main/bash/lv_snapper) [`New`] Pre/post scripts to snapshot an LVM volume

## 2024-08-11

* [generateAgentCertificate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/generateAgentCertificate) [`New`] Generate new agent certificate
* [replaceWindowsAgentCertificate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replaceWindowsAgentCertificate) [`New`] Remotely replace agent certificate on Windows host

## 2024-08-10

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added text mode output
* [generateAgentCertificate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/generateAgentCertificate) [`New`] Generate new agent certificate
* [replaceLinuxAgentCertificate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replaceLinuxAgentCertificate) [`New`] Remotely replace agent certificate on Linux host
* [agentCertificateCheck.py](https://github.com/cohesity/community-automation-samples/tree/main/python/agentCertificateCheck) [`Update`] Added check for matching subject alternate name

## 2024-08-09

* [agentSummaryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentSummaryReport) [`New`] Generate an agent summary report
* [agentSummaryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/agentSummaryReport) [`New`] Generate an agent summary report

## 2024-08-08

* [clusterNumberOfProtectedVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterNumberOfProtectedVMs) [`New`] Report number of protected VMware VMs per cluster

## 2024-08-07

* [policyTool7.py](https://github.com/cohesity/community-automation-samples/tree/main/python/policyTool) [`New`] create and edit policies. This version supports calendar based scheduling introduced in Cohesity 7.x

## 2024-08-05

* [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] added -jobName parameter

## 2024-08-01

* [unprotectCCSEC2VMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCCSEC2VMs) [`New`] Unprotect CCS EV2 VMs

## 2024-07-31

* [clusterInfo.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterInfo) [`Fix`] fixed crash when nodeInfo not available
* [directoryQuota.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/directoryQuota) [`Update`] added paging to API call
* [restoreSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQL) [`Update`] added -returnErrorMessage option

## 2024-07-30

* [cert.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cert) [`Update`] updated supported version check

## 2024-07-26

* [resetBSODCounters.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resetBSODCounters) [`New`] reset BSOD counter for CBT driver on Windows
* [protectLinux.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux) [`Fix`] removed old volume type exclusion code

## 2024-07-25

* [replicationQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replicationQueue) [`Update`] added -before and -after parameters
* [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Fix`] added resilience to timeouts while checking for completion status

## 2024-07-24

* [updateJobSettings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateJobSettings) [`Update`] added -a (--alertonslaviolation) parameter
* [downloadCcsM365MailboxItems.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/downloadCcsM365MailboxItems) [`New`] download mailbox items as PST from a CCS M365 mailbox.

## 2024-07-23

* [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`Update`] added -f (--freespacemultiplier) to check for enough free space
* [crowdstrikeReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/crowdstrikeReport) [`New`] report physical/virtual servers and their latest version of the affected CrowdStrike update file.
* [crowdstrikeReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/crowdstrikeReport) [`New`] report physical/virtual servers and their latest version of the affected CrowdStrike update file.

## 2024-07-19

* [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] added -overwrite parameter
* [protectIsilon.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectIsilon) [`New`] protect Isilon volumes using PowerShell
* [protectIsilon.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectIsilon) [`Update`] modernized authentication

## 2024-07-18

* [clusterStorageStats.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterStorageStats) [`Update`] added "usable" output (vs raw)

## 2024-07-17

* [archiveOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveOldSnapshots) [`Fix`] fixed date filtering issue
* [s3](https://github.com/bseltz-cohesity/scripts/tree/master/s3) [`New`] Several scripts in python and bash for accessing Cohesity S3 views

## 2024-07-16

* [replicationQueue.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/replicationQueue) [`Fix`] fixed time range bug
* [deletedProtectionGroups.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/deletedProtectionGroups) [`New`] remove deleted protection groups

## 2024-07-12

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Fix`] minor cosmetic error
* [replicationQueue.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicationQueue) [`Update`] added --joblist parameter

## 2024-07-11

* [policyTool.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/policyTool) [`Update`] added -noAuth option for multi-policy edits

## 2024-07-10

* [legalHold.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHold) [`Update`] added -rl, --runidlist parameter to allow input of a list of runids

## 2024-07-08

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] reintroduced -keepLocalFor functionality
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] reintroduced -k, --keepLocalFor functionality
* [mountOracleAsView.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/mountOracleAsView) [`Fix`] fixed snapshot sort order
* [recoverNASVolume.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverNASVolume) [`New`] recover NAS volume to original or new location

## 2024-07-04

* [validateServerBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateServerBackups) [`Update`] validate all applicable backups if not objects are specified

## 2024-06-28

* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Update`] improved used size for physical volume based servers and Active Directory backups
* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] improved used size for Active Directory backups

## 2024-06-27

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Update`] improved used size for physical volume based servers
* [updateWindowsAllDrives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateWindowsAllDrives) [`New`] Update Windows File-Based Protection to Protect All Local Drives
* [updateWindowsAllDrives.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateWindowsAllDrives) [`New`] Update Windows File-Based Protection to Protect All Local Drives
* [storagePerObjectReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/storagePerObjectReport) [`Fix`] fixed protected view consumption calculation

## 2024-06-26

* [storagePerObjectReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/storagePerObjectReport) [`Fix`] fixed protected view consumption calculation

## 2024-06-25

* [registerPhysical.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerPhysical) [`Fix`] fixed error when no existing physical sources are registered

## 2024-06-24

* [restartFailedJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restartFailedJobs) [`Update`] added option to only restart sources that failed with transport error
* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed SaaS connector authentication error: KInvalidError
* [updateSaaSconnectorPassword.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/updateSaaSconnectorPassword) [`New`] update admin password on SaaS connector
* [protectLinux.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux) [`Update`] added -al, --alerton and -ar --recipients parameters
* [protectUDA.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectUDA) [`Update`] added -al, --alerton and -ar --recipients parameters
* [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileFiles) [`Update`] added support for multiple search strings

## 2024-06-16

* [updateJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJob) [`Update`] added controls for job alerts

## 2024-06-14

* [mountOracleAsView.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/mountOracleAsView) [`Update`] added -cc, --channelcount parameter

## 2024-06-13

* [migrateIsilonProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateIsilonProtectionGroup) [`New`] Migrate Isilon protection group to another cluster
* [migrateNetappProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateNetappProtectionGroup) [`New`] Migrate Netapp protection group to another cluster

## 2024-06-12

* [updateAWSExternalTargetCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateAWSExternalTargetCredentials) [`New`] Update AWS external target access key and secret key

## 2024-06-07

* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added -maxrecords tuning parameter
* [upgradeCluster.py](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeCluster) [`Update`] modernized authentication
* [protectNetapp.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectNetapp) [`Update`] added verbose output to screen
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Update`] added support for Entra ID authentication
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added support for Entra ID authentication to Helios

## 2024-06-06

* [updateVcenterCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateVcenterCredentials) [`New`] update vCenter source credentials
* [restoreUDA.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreUDA) [`Fix`] reordered snapshot selection by date

## 2024-06-05

* [validateVMBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateVMBackups) [`Fix`] added kWarning status
* [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Update`] modernized authentication
* [isilon_api.py](https://github.com/cohesity/community-automation-samples/tree/main/python/isilon_api) [`New`] API helper for Isilon scripts
* [isilonCFTtest.py](https://github.com/cohesity/community-automation-samples/tree/main/python/isilonCFTtest) [`Update`] updated to support session cookie authentication

## 2024-06-04

* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Fix`] fixed shellvars syntax error

## 2024-06-03

* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Fix`] fixed unintended replication/archival
* [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) [`Fix`] fixed unintended replication/archival

## 2024-05-30

* [isilon-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilon-api) [`New`] API helper for Isilon scripts
* [isilonCFTtest.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilonCFTtest) [`Update`] updated to support session cookie authentication
* [isilonCreateCohesityUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilonCreateCohesityUser) [`Update`] updated to support session cookie authentication

## 2024-05-28

* [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`Update`] expanded ignore paths
* [cancelCcsProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/cancelCcsProtectionRuns) [`Update`] added -sourceName and -objectName parameters

## 2024-05-23

* [viewDRtest](https://github.com/cohesity/community-automation-samples/tree/main/powershell/ViewDRtest) [`New`] clone views for DR testing

## 2024-05-22

* [jobRunning.py](https://github.com/cohesity/community-automation-samples/tree/main/python/jobRunning) [`Update`] modernized authentication options
* [unprotectPhysicalServer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectPhysicalServer) [`Update`] modernized authentication options

## 2024-05-21

* [restoreSQL-CCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/restoreSQL-CCS) [`Update`] added -logRangeDays parameter to limit scope of log lookups
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] added -logRangeDays parameter to limit scope of log lookups
* [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`New`] obfuscate paths in log files before uploading to Cohesity Support
* [heliosLicenseReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/python/heliosLicenseReport) [`Update`] added CSV output format

## 2024-05-18

* [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) [`Update`] added -protectionGroup parameter
* [registerVcenter.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerVcenter) [`Update`] added -useVmBiosUuid parameter
* [listViews.py](https://github.com/cohesity/community-automation-samples/tree/main/python/listViews) [`Update`] updated to use v2 API

## 2024-05-17

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added support for Entra ID authentication to Helios
* [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) [`Update`] added support for Entra ID authentication to Helios

## 2024-05-16

* [deployCCSWindowsAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/deployCCSWindowsAgent) [`New`] Remotely install and register Windows agents for CCS
* [oracleLogDeletionDaysReport.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/oracleLogDeletionDaysReport) [`Update`] added number of channels to output
* [createNFSView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createNFSView) [`Update`] added support for NFSv4.1
* [clusterIPs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/clusterIPs) [`Update`] added support for secondary interface IPs

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
* [protectSQLServer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/protectSQLServer) [`Update`] added option to enable source side deduplication (for file-based protection type only)
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
* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Fix`] added several validation checks for negative search results

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
* [protectSQLServer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/protectSQLServer) [`Update`] added -unprotectedDBs parameter
* [changeLocalRetention.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/changeLocalRetention) [`Update`] added -jobList parameter
* [protectCcsM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Mailboxes) [`Update`] added support for security groups
* [smbFileOpens](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/smbFileOpens) [`Update`] added path filter

## 2024-01-18

* [legalHoldList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/legalHoldList) [`Update`] moderized authentication

## 2024-01-17

* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Fix`] added validation of target instance name

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
