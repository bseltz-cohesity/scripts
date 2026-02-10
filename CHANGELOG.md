# Change Log for cohesity/community-automation-samples

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

* [CHANGELOG 2025](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2025.md)
* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2023.md)
