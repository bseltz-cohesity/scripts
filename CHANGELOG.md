# Change Log for cohesity/community-automation-samples

* [`2026-04-11`] [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) [`Update`] added custom rules option
* [`2026-04-11`] [backupNowCcs-multi.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs-multi) [`Update`] added -sourceName parameter
* [`2026-04-10`] [legalHoldAll.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/legalHoldAll) [`Update`] added date range filters
* [`2026-04-07`] [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] added -flatFilePath option to restore databases as flat files
* [`2026-04-03`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] find secrets in environment variables
* [`2026-04-03`] [envname.py](https://github.com/cohesity/community-automation-samples/tree/main/python/envname) [`Update`] report which environment variables to use with pyhesity
* [`2026-03-31`] [restoreFiles.exe](https://github.com/cohesity/community-automation-samples/tree/main/windows/restoreFiles) [`Update`] update to latest code from restoreFiles.py
* [`2026-03-31`] [legalHoldCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/legalHoldCCS) [`Update`] rewrite for scalability
* [`2026-03-31`] [protectCcsM365OneDriveCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365OneDriveCSV) [`Update`] added -pause -resume options
* [`2026-03-30`] [jobReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/jobReport) [`Update`] fix for running jobs
* [`2026-03-30`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] Updated Helios auth exception handling
* [`2026-03-30`] [fileSearch.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileSearch) [`New`] File search for PowerShell
* [`2026-03-27`] [protectCcsM365MailboxesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365MailboxesCSV) [`Update`]
* [`2026-03-27`] [legalHoldCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/legalHoldCCS) [`Update`] fixed timestamp issue
* [`2026-03-25`] [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] README fix
* [`2026-03-25`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] fixed org support for Helios
* [`2026-03-25`] [protectView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectView) [`Update`] modernized authentication
* [`2026-03-25`] [createS3View.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createS3View) [`Update`] updated to v2 API, added support for helios
* [`2026-03-24`] [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Update`] made folder name optional
* [`2026-03-23`] [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] fixed missing old backups
* [`2026-03-18`] [protectCassandra.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectCassandra) [`Update`] added alert recipient validation and removal
* [`2026-03-17`] [heliosClusterConfigBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosClusterConfigBackups) [`New`] report cluster backups in Helios
* [`2026-03-17`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] added -j, --jobname parameter
* [`2026-03-16`] [deployHSM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployHSM) [`New`] deploy Helios Self-Managed virtual edition
* [`2026-03-16`] [heliosSMBackups.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/python/heliosSMBackups) [`New`] report Helios Self-Managed backups
* [`2026-03-16`] [heliosSMBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosSMBackups) [`New`] report Helios Self-Managed backups
* [`2026-03-12`] [autoprotectM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/autoprotectM365Mailboxes) [`New`] protect M365 Mailboxes (customer-managed)
* [`2026-03-12`] [unprotectCcsM365GroupsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365GroupsCSV) [`New`] unprotect M365 Groups from CSV file
* [`2026-03-11`] [fileSearch.py](https://github.com/cohesity/community-automation-samples/tree/main/python/fileSearch) [`Update`] added -runid option
* [`2026-03-11`] [protectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365SitesCSV) [`Update`] added -autoprotectCount option
* [`2026-03-11`] [protectCcsM365GroupsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365GroupsCSV) [`Update`] added -autoprotectCount option
* [`2026-03-11`] [protectCcsM365TeamsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365TeamsCSV) [`Update`] added -autoprotectCount option
* [`2026-03-11`] [protectCcsM365OneDriveCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365OneDriveCSV) [`Update`] added -autoprotectCount option
* [`2026-03-09`] [unprotectCcsM365OneDriveCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365OneDriveCSV) [`New`] unprotect M365 OneDrives from CSV file
* [`2026-03-06`] [clusterInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterInfo) [`Update`] added VIPs
* [`2026-03-05`] [clusterProtectionRuns.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/clusterProtectionRuns) [`Update`] added --lastrunonly option
* [`2026-03-04`] [jobReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/jobReport) [`New`] report last run info per protection group
* [`2026-03-04`] [protectCcsM365MailboxesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365MailboxesCSV) [`Update`] added -autoprotectCount option
* [`2026-03-03`] [unprotectCcsM365MailboxesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectCcsM365MailboxesCSV) [`New`] unprotect M365 mailboxes from CSV file
* [`2026-03-03`] [protectCcsM365OneDriveCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365OneDriveCSV) [`New`] protect M365 OneDrives from CSV file
* [`2026-03-03`] [protectCcsM365MailboxesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365MailboxesCSV) [`New`] protect M365 mailboxes from CSV file
* [`2026-03-02`] [unprotectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/unprotectccsM365SitesCSV) [`New`] unprotect M365 sites from CSV file
* [`2026-03-02`] [protectCcsM365GroupsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365GroupsCSV) [`Update`] skip team groups
* [`2026-03-01`] [heliosVEBackup.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/heliosVEBackup) [`New`] backup Helios virtual edition VMs
* [`2026-03-01`] [heliosMonitor.py](https://github.com/cohesity/community-automation-samples/tree/main/python/heliosMonitor) [`New`] monitor Helios self-managed startup
* [`2026-03-01`] [vmMacAddresses.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/vmMacAddresses) [`New`] report VVMware VM MAC addresses
* [`2026-03-01`] [shutdownVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/shutdownVMs) [`New`] shutdown VMware VMs
* [`2026-03-01`] [powerOnVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/powerOnVMs) [`New`] power on VMware VMs
* [`2026-02-28`] [protectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365SitesCSV) [`Update`] skip group/team sites
* [`2026-02-27`] [recoverAHVVMs-throttledV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs-throttled) [`Update`] 7.3.2 update to support preserve MAC address
* [`2026-02-27`] [recoverAHVVMsV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs) [`Update`] 7.3.2 update to support preserve MAC address
* [`2026-02-27`] [heliosVEbackup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/heliosVEbackup) [`New`] backup Helios virtual edition VMs
* [`2026-02-25`] [recoverAHVVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs) [`Update`] added preserve Mac address option
* [`2026-02-25`] [recoverAHVVMs-throttled.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverAHVVMs-throttled) [`Update`] added preserve Mac address option
* [`2026-02-25`] [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] added object search
* [`2026-02-25`] [protectAHVVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectAHVVMs) [`Update`] update disk exclusions for already protected VMs
* [`2026-02-25`] [protectAHVVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectAHVVMs) [`Update`] update disk exclusions for already protected VMs
* [`2026-02-24`] [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] updated runs query
* [`2026-02-24`] [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Update`] added snapshot expiration date
* [`2026-02-24`] [protectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365SitesCSV) [`Update`] protect sub-sites
* [`2026-02-23`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] fixed snapshot selection
* [`2026-02-20`] [backupGitHub-mirror.sh](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/backupGitHub) [`New`] Backup GitHub using --mirror option
* [`2026-02-18`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] updated -dbg to functionality
* [`2026-02-16`] [restoreMongoDBOpsManager.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreMongoDBOpsManager) [`New`] restore MongoDB Ops Manager
* [`2026-02-16`] [powershell_compatible_cleanup_script.ps1](https://github.com/cohesity/community-automation-samples/tree/main/cloud/cleanupSnapshots) [`Update`] code update
* [`2026-02-13`] [protectMongoDBOpsManager.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectMongoDBOpsManager) [`New`] protect MongoDB Ops Manager
* [`2026-02-13`] [protectCcsM365GroupsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365GroupsCSV) [`New`] new script variant to take input from CSV file
* [`2026-02-13`] [protectCcsM365TeamsCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365TeamsCSV) [`New`] new script variant to take input from CSV file
* [`2026-02-12`] [registerMongoDBOpsManager.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerMongoDBOpsManager) [`New`] register a MongoDB Ops Manager protection source
* [`2026-02-11`] [createNFSView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createNFSView) [`Update`] fix QOS name 7.3.1
* [`2026-02-11`] [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) [`Update`] update for runs list
* [`2026-02-10`] [unprotectCcsObjects.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/unprotectCcsObjects) [`Update`] fix objectId issue
* [`2026-02-10`] [overwriteView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/overwriteView) [`New`] overwrite a view
* [`2026-02-10`] [legalHold.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHold) [`Update`] fixed TypeError: 'int' object is not iterable
* [`2026-02-09`] [smbPermissions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbPermissions) [`Update`] added support for local users and groups
* [`2026-02-06`] [sqlJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlJobSelections) [`Update`] added protection type column to output
* [`2026-02-05`] [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) [`Update`] remove debug statements
* [`2026-02-05`] [ccsSlaMonitor.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/ccsSlaMonitor) [`New`] Monitor SLA violations in CCS
* [`2026-02-03`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added pauseCohesityAPIDebugger and resumeCohesityAPIDebugger functions
* [`2026-02-03`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added pauseCohesityAPIDebugger and resumeCohesityAPIDebugger functions
* [`2026-02-02`] [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added enableCohesityAPIDebugger function (output cohesity-har-file.txt)
* [`2026-02-01`] [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added enableCohesityAPIDebugger function (output cohesity-har-file.txt)
* [`2026-02-01`] [protectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365SitesCSV) [`Update`] added -dbg switch (enableCohesityAPIDebugger)
* [`2026-01-30`] [policyTool.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/policyTool) [`Update`] fix for calendar based scheduling
* [`2026-01-29`] [enableDatalock.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/enableDatalock) [`Update`] fix for calendar based scheduling
* [`2026-01-29`] [epic_pure_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/epic_pure_freeze_thaw) [`Update`] fix for AIX syntax error
* [`2026-01-22`] [ccsActivityReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/ccsActivityReport) [`New`] generate a CCS activity report
* [`2026-01-18`] [migrateGenericNasProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateGenericNasProtectionGroup) [`Update`] added support for NGCE
* [`2026-01-18`] [migrateSQLProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateSQLProtectionGroup) [`Update`] added support for NGCE
* [`2026-01-18`] [migratePhysicalProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migratePhysicalProtectionGroup) [`Update`] added support for NGCE
* [`2026-01-17`] [migrateUsersAndGroups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateUsersAndGroups) [`Update`] scalability improvements
* [`2026-01-16`] [migrateProtectionPolicy.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateProtectionPolicy) [`Update`] added support for NGCE
* [`2026-01-16`] [migrateEC2ProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateEC2ProtectionGroup) [`Update`] added support for NGCE
* [`2026-01-14`] [backupGitHub.sh](https://github.com/cohesity/community-automation-samples/tree/main/remoteAdapter/backupGitHubV2) [`New`] Advanced remote adapter script for GitHub backups
* [`2026-01-14`] [clusterInfo.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/clusterInfo) [`Update`] added network bond names and speeds
* [`2026-01-13`] [ccsM365MailboxExcludedFolders.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/ccsM365MailboxExcludedFolders) [`New`] list the excluded folders for protected M365 mailboxes
* [`2026-01-09`] [netappImportShares.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netappImportShares) [`Update`] updated to support BUILTIN principals
* [`2026-01-08`] [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/findFiles) [`Update`] added -lastBackupOnly switch
* [`2026-01-07`] [clusterProtectionRuns.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterProtectionRuns) [`Update`] added -onHoldOnly switch to report objects that are on legalHold
* [`2026-01-06`] [protectCcsM365SitesCSV.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`New`] new script variant to take input from CSV file
* [`2026-01-06`] [powershell_compatible_cleanup_script.ps1](https://github.com/cohesity/community-automation-samples/tree/main/cloud/cleanupSnapshots) [`Update`] updated code from author
* [`2026-01-05`] [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] added -ds, --dontskipclonenid option
* [`2026-01-02`] [expireOldSnapshots.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldSnapshots) [`Update`] updated error catching
* [`2026-01-02`] [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] fixed range selection issue

## Old Change Logs

* [CHANGELOG 2025](https://github.com/cohesity/community-automation-samples/blob/main/Old-CHANGELOG-2025.md)
* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/blob/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/blob/main/Old-CHANGELOG-2023.md)
