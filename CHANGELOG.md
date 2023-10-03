# Change Log for bseltz-cohesity/scripts

## 2023-10-03

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/pyhesity> [`Fix`] fixed 'forcePasswordChange' error on AD authentication

## 2023-10-02

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Fix`] cosmetic bug 'An item with the same key has already been added. Key: content-type'
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/registerPhysical> [`Update`] added support for multitenancy
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/chargebackReport> [`Fix`] added lower bound `startTimeUsecs` to query parameters

## 2023-09-29

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/featureFlags> [`New`] Python script to get, set, export and import feature flags
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/featureFlags> [`New`] PowerShell script to get, set, export and import feature flags

## 2023-09-28

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/activeSnapshotsRemote> [`New`] Script to determine count, oldest, and newest backups available on replica cluster (that can't be queried directly, e.g. isolated vault cluster)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/archiveQueue> [`Update`] don't show expired archives when using `-showFinished``

## 2023-09-26

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports> [`Update`] Renamed heliosV2 folder to helios and renamed heliosV1 folder to helios-old

## 2023-09-24

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/pyhesity> [`Update`] minor refactoring
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Update`] minor refactoring

## 2023-09-23

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Update`] switched to web session authentication, added support for password reset. email MFA
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/gflags> [`Update`] switched to web session authentication
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/pyhesity> [`Update`] switched to web session authentication, added support for password reset, email MFA
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/gflagList> [`Update`] switched to web session authentication
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/gflags> [`Update`] switched to web session authentication

## 2023-09-22

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/replicationQueue> [`Update`] added option to cancel outdated/all replications per job, per target
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/licenseCluster> [`New`] generates a license from Helios and applies it to a cluster
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Update`] added file upload function to support the new licenseCluster script

## 2023-09-21

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/strikeReportV2> [`Fix`] bug fix

## 2023-09-19

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/replicationReport> [`Update`] Performance improvement
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport> [`Update`] added tenant column
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport> [`Update`] added tenant column
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/findFilesV2> [`New`] New script to search for indexed files

## 2023-09-18

* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/oracleLogDeletionDaysReport> [`Fix`] abend on missing database ID

## 2023-09-16

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/unregisterProtectionSource> [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectVM> [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/unprotectVM> [`Update`] modernized authentication (added MFA, multi-tenancy, etc)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/migratePhysicalProtectionGroup> [`Update`] added support for multi-tenancy
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/migrateSQLProtectionGroup> [`Update`] added support for multi-tenancy
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/migrateVMProtectionGroup> [`Update`] added support for multi-tenancy

## 2023-09-15

* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/oracleLogDeletionDaysReport> [`New`] report oracle archive log deletion settings
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/dataReadPerVMReport> [`Update`] Improved dataRead adjustment logic

## 2023-09-14

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/strikeReportV2> [`Update`] added sourceName column

## 2023-09-13

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backupNow> [`Update`] Improved error handling on start
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow> [`Update`] Improved error handling on start

## 2023-09-12

* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/aagFailoverMinder> [`Fix`] wait for application refresh

## 2023-09-11

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/heliosV2/powershell/heliosCSVReport> [`New`] script to generate Helios reports in raw CSV format (much faster than heliosReport.ps1)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/resetMyExpiredPassword> [`New`] script to reset my expired password

## 2023-09-08

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/protectGPFS> [`New`] python script to protect GPFS Filesets (agent-based approach)

## 2023-09-07

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/pauseResumeJobs.py> [`Update`] added show mode
* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/protectOracle> [`Update`] added --noalert option
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/refreshSource> [`Fix`] wait for app/DB refresh
* <https://github.com/bseltz-cohesity/scripts/tree/master/aix> [`Update`] Added MFA support to compiled binaries for AIX
* <https://github.com/bseltz-cohesity/scripts/tree/master/linux> [`Update`] Added MFA support to compiled binaries for Linux
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow> [`Update`] Added MFA support
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backedUpFileList> [`Update`] Added MFA support
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/restoreFiles> [`Update`] Added MFA support

## 2023-09-06

* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/pyhesity> [`Update`] added timeout parameter to apiauth and api functions (required for latest version of backupNow.py)
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cancelArchivesV2> [`Update`] added support to filter on target name
* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/protectOracle> [`Fix`] fixed edge case bug that caused unhandled exception
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backupNow> [`Update`] performance improvements
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow> [`Update`] performance improvements

## 2023-09-04

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/gflags> [`Fix`] Fixed service restart function

## 2023-09-03

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backupNow> [`Update`] performance improvements
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow> [`Update`] performance improvements

## 2023-08-31

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/recoverHyperVVMs> [`Update`] added support for restore to stand alone failover clusters and stand alone hosts

## 2023-08-30

* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/unprotectDmaasM365Mailboxes> [`Update`] added support for mailbox selection by UUID
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerVMReport> [`New`] new script to report storage consumed per VMware VM
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/instantVolumeMount> [`Updated`] added support for v2 runid format
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/updateJobSettings> [`New`] New script to update common protection group settings

## 2023-08-28

* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/protectOracle> [`Updated`] added additional parameters
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Updated`] added offending line number to cohesity-api-debug.log

## 2023-08-27

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/archiveQueue> [`Update`] added exit 0 when no active archive tasks found, exit 1 if tasks are found
* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/aagFailoverMinder> [`Fixed`] updated run payload to remove kLocal copyRun
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/updateAWSCredentials> [`New`] new python script to update access key / secret key for AWS source.

## 2023-08-22

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/expireOldArchives> [`Update`] added modern authentication support
* <https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/registerOracle> [`Fix`] fixed error that occured when no Oracle sources were present on the cluster

## 2023-08-19

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/addObjectToUserAccessList> [`Update`] added support for AD groups

## 2023-08-17

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/updateGCPExternalTargetPrivateKey> [`New`] PowerShell script to update the private key on a Google Cloud archive target
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/expireOldSnaps> [`Update`] added modern authentication methods (API keys, MFA, Helios, etc)
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport> [`Update`] added estimated archival usage per object
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport> [`Update`] added estimated archival usage per object
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/activeSnapshots> [`Update`] added support for multitenancy
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/updateJobDescriptions> [`New`] PowerShell script to update protection group descriptions from a CSV file

## 2023-08-16

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/restoreReport> [`Update`] added recoery point to output
* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQL> [`Fix`] Fixed cosmetic error "Cannot index into a null array" when checking previous restores during resume recovery

## 2023-08-15

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api> [`Fix`] Enforce TLSv1.2 to solve TLSv1.3 handshake failures with PowerShell.Core on Windows Server 2022

## 2023-08-14

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/strikeReportV2> [`Fix`] parsing misbehavior on Windows PowerShell 5.1
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backupNow> [`Fix`] updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED"
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow> [`Fix`] updated script to exit with failure on "TARGET_NOT_IN_POLICY_NOT_ALLOWED"

## 2023-08-12

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/updateArchiveRetention> [`Fix`] fixed filter by policy names
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/usersAndGroups> [`New`] report list of users and groups

## 2023-08-11

* <https://github.com/bseltz-cohesity/scripts/tree/master/linux/backedUpFileList> [`New`] compiled binary version of backedUpFileList for Linux
* <https://github.com/bseltz-cohesity/scripts/tree/master/linux/restoreFiles> [`New`] compiled binary version of restoreFiles for Linux
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/gflagList> [`New`] get complete list of gflags for a service
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/unprotectDmaasM365Mailboxes> [`New`] unprotect M365 mailboxes in CCS

## 2023-08-10

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/clusterProtectedObjects> [`New`] cluster-direct API script to generate protected objects report
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/clusterProtectionRuns> [`Fix`] performance improvement

## 2023-08-09

* <https://github.com/bseltz-cohesity/scripts/tree/master/python/expireOldSnapshots> [`Update`] added `-s`, `--skipmonthlies` parameter
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport> [`Update`] updated storage calculations

## 2023-08-02

* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/protectedFilePathReport> [`Update`] added output column for skipNestedVolumes

## 2023-08-01

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectO365OneDrive> [`Update`] added support for UUIDs as input list of users to protect
* <https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport> [`Update`] added recent growth column to the output

## 2023-07-31

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectVM> [`Fix`] fixed disk exclusions
* <https://github.com/bseltz-cohesity/scripts/tree/master/python/protectMongoDB> [`Update`] exit with 0 on no databases to protect

## 2023-07-30

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectWindows> [`Fix`] remove null entry from exclude paths
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/globalExcludePaths> [`Fix`] remove null entry from exclude paths

## 2023-07-29

* <https://github.com/bseltz-cohesity/scripts/tree/master/bash/epic_pure_freeze_thaw> [`Update`] parameterized configuration variables and added autodetection of OS (Linux or AIX)

## 2023-07-27

* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/addGlobalExcludePaths> [`Fix`] remove null entry from exclude paths
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/cancelDmaasProtectionRuns> [`Update`] added -subType filter (e.g. kO365Sharepoint)
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Groups> [`Update`] updated to support autoselect of groups with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Teams> [`Update`] updated to support autoselect of teams with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Sites> [`Update`] updated to support autoselect of sites with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectLinux> [`Fix`] remove null entry from exclude paths
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cloneVM> [`Fix`] cluster/host not found error due to unexpected sorting in object hierarchy
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/viewDR> [`Update`] replicateViews.ps1 and added replication completion check to cleanupJobs.ps1

## 2023-07-26

* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQL> [`Fix`] Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQLDBs> [`Fix`] Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cloneVM> [`Fix`] Updated resource pool search to provide clearer error message when compute resource not found.

## 2023-07-20

* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/backedUpFileList> [`New`] backedUpFileList for AIX

## 2023-07-19

* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/restoreFiles> [`New`] restoreFiles for AIX
* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/backupNow> [`Fix`] backupNow for AIX fix for 6.8.1 P11 / 6.6.0 P34 error: "TARGET_NOT_IN_POLICY_NOT_ALLOWED%!(EXTRA int64=0)"
