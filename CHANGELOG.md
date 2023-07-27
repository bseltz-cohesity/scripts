# Change Log for bseltz-cohesity/scripts

## 2023-07-27

* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/cancelDmaasProtectionRuns> Feature: added -subType filter (e.g. kO365Sharepoint)
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Groups> Fix: updated to support autoselect of groups with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Teams> Fix: updated to support autoselect of teams with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Sites> Fix: updated to support autoselect of sites with non-unique names
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectLinux> Fix: remove null entry from exclude paths
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cloneVM> Fix: cluster/host not found error due to unexpected sorting in object hierarchy
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/viewDR> New script: replicateViews.ps1 and added replication completion check to cleanupJobs.ps1

## 2023-07-26

* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQL> Fix: Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* <https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQLDBs> Fix: Updated search time range for the latest log backup that might be arbitrarily old (previously only looked 3 days back).
* <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cloneVM> Fix: Updated resource pool search to provide clearer error message when compute resource not found.

## 2023-07-20

* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/backedUpFileList> New Script: backedUpFileList for AIX

## 2023-07-19

* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/restoreFiles> New script: restoreFiles for AIX
* <https://github.com/bseltz-cohesity/scripts/tree/master/aix/backupNow> Fix: backupNow for AIX fix for 6.8.1 P11 / 6.6.0 P34 error: "TARGET_NOT_IN_POLICY_NOT_ALLOWED%!(EXTRA int64=0)"
