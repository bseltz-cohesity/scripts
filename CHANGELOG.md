# Change Log for bseltz-cohesity/scripts

## 2023-08-16

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
