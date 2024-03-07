# Change Log for bseltz-cohesity/scripts

## 2024-03-06

* [heliosUsers.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/helios-other/powershell/heliosUsers) [`Updated`] Added created time to report output
* [backupNow.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow) [`Update`] moved read replica cache wait to after authentication
* [gflags.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/gflags) [`Fix`] fixed clear option
* [gflags.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/gflags) [`Fix`] fixed clear option

## 2024-03-05

* [protectWindows.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/protectWindows) [`Update`] modernized authentication

## 2024-03-04

* [cloneOracle.py](https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/cloneOracle) [`Fix`] fixed error "NameError: name 'targetEntity' is not defined" when target server is not found

## 2024-03-03

* [protectSQL.py](https://github.com/bseltz-cohesity/scripts/tree/master/sql/python/protectSQL) [`New`] consolidated script to protect SQL servers, instances, databases

## 2024-03-02

* [protectSQL.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/sql/powershell/protectSQL) [`New`] consolidated script to protect SQL servers, instances, databases (protectSQLDB.ps1 and protectSQLServer.ps1 have been replaced)
* [sql](https://github.com/bseltz-cohesity/scripts/tree/master/sql) [`Update`] moved SQL scripts into sql/powershell and sql/python folders

## 2024-03-01

* [directiveBackupHistoryReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/directiveBackupHistoryReport) [`New`] report directive files used for physical server file-based backups over the past X days
* [excludeSQLDBs.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/excludeSQLDBs) [`New`] Add/remove exclusions for SQL protection groups

## 2024-02-29

* [restoreFiles.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/restoreFiles) (PowerShell) [`Update`] added -isilonZoneId parameter
* [pauseProtectionActivity.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/pauseProtectionActivity) [`Update`] added wait for service restart at end of script
* [storagePerObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport) [`Update`] Added -consolidateDBs option

## 2024-02-28

* [storagePerObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport) [`Update`] Added Cluster Used and Reduction columns
* [storagePerObjectReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport) [`Update`] Added Cluster Used and Reduction columns
* [cohesity-api.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api) [`Update`] added support for helios.gov
* [pyhesity.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/pyhesity) [`Update`] added support for helios.gov
* [restoreOracle-v2.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/oracle/powershell/restoreOracle-v2) [`Fix`] fixed CDB recovery (overwrite original DB)

## 2024-02-27

* [restoreOracle-v2.py](https://github.com/bseltz-cohesity/scripts/tree/master/oracle/python/restoreOracle-v2) [`Fix`] fixed CDB recovery (overwrite original DB)

## 2024-02-24

* [physicalBackupPathsReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/physicalBackupPathsReport) [`Update`] Output to CSV
* [physicalBackupPathsHistoryReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/physicalBackupPathsHistoryReport) [`New`] History report of paths backed up from physical servers

## 2024-02-22

* [ccsSlaMonitor.py](https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/python/ccsSlaMonitor) [`New`] Monitor for SLA violations in CCS

## 2024-02-21

* [protectCCSEC2VMs.py](https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/python/protectCCSEC2VMs) [`New`] Protect EC2 VMs in CCS
* [nodeStatus.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/nodeStatus) [`New`] report node status

## 2024-02-19

* [backupNow.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backupNow) [`Update`] expanded existing run string matches
* [backupNow.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/backupNow) [`Update`] expanded existing run string matches

## 2024-02-18

* [clusterProtectionRuns.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/clusterProtectionRuns) [`Fix`] fixed units in heading
* [cohesity-api.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api) [`Fix`] toJson function - handle null input

## 2024-02-16

* [expireOldSnapshots.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/expireOldSnapshots) [`Fix`] handle missing clusterName property in replication target history

## 2024-02-15

* [registerPhysical.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/registerPhysical) [`Update`] added option to set network throttling to X MB/sec and added ability to update existing sources
* [storagePerObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport) [`Update`] Added Storage Domain and Front End allocated columns
* [storagePerObjectReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport) [`Update`] Added Storage Domain and Front End allocated columns

## 2024-02-14

* [registerUDA.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/registerUDA) [`Fix`] added --ostype parameter

## 2024-02-09

* [protectedObjectReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/protectedObjectReport) [`Update`] added support for cloudArchive direct
* [protectedObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/protectedObjectReport) [`Update`] added support for cloudArchive direct

## 2024-02-07

* [findAndRestoreFiles.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/findAndRestoreFiles) [`Update`] added -targetRegisteredSource to refine selection of -targetObject
* [legalHoldAll.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/legalHoldAll) [`Update`] report if backup on legal hold is past its intended expiration date

## 2024-02-06

* [clusterProtectionRuns.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/clusterProtectionRuns) [`Update`] added support for cloudArchive Direct
* [protectSQLServer.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/sql/protectSQLServer) [`Update`] added option to enable source side deduplication (for file-based protection type only)
* [backedUpFileList.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/backedUpFileList) [`Fix`] handle missing attemptNum property
* [backedUpFileList.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/backedUpFileList) [`Fix`] handle missing attemptNum property

## 2024-02-02

* [restoreSQL-CCS.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/restoreSQL-CCS) [`Update`] added support for SQL Always On Availability Group datbases

## 2024-02-01

* [storagePerObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport) [`Update`] Added support for CloudArchive Direct jobs
* [storagePerObjectReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport) [`Update`] Added support for CloudArchive Direct jobs

## 2024-01-31

* [backedUpFSReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/backedUpFSReport) [`Update`] added -s (--search) and -e (--exactmatch) parameters
* [runsExample.sh](https://github.com/bseltz-cohesity/scripts/tree/master/bash/runsExample) [`New`] bash example using curl and jq to walk through protection groups and runs

## 2024-01-27

* [restoreReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/restoreReport) [`Update`] added support for cart-based SQL restores

## 2024-01-26

* [restartFailedJobs.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/restartFailedJobs) [`New`] find and restart any failed jobs
* [restoreSQLv2.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQLv2) [`Fix`] added several validation checks for negative search results

## 2024-01-25

* [cohesity-api.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api) [`Fix`] added support for unicode characters in JSON payloads (affected Windows PowerShell 5.1)

## 2024-01-24

* [epic_vm_freeze_thaw.sh](https://github.com/bseltz-cohesity/scripts/tree/master/bash/epic_vm_freeze_thaw) [`New`] VMware Freeze/thaw script for Epic

## 2024-01-22

* [userApiKeys.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/userApiKeys) [`New`] List, activate and deactivate user API Keys

## 2024-01-20

* [registeredSources.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/registeredSources) [`Fix`] fixed windows bug and garbled date format

## 2024-01-19

* [agentStatus.ps1](https://github.com/bseltz-cohesity/scripts/tree/8e79c66c685157d9df2f1e3b893b4d24de70e0b0/reports/powershell/agentStatus) [`Removed`] this script has been superceded by [registeredSources.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/registeredSources)
* [protectSQLServer.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/sql/protectSQLServer) [`Update`] added -unprotectedDBs parameter
* [changeLocalRetention.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/changeLocalRetention) [`Update`] added -jobList parameter
* [protectDmaasM365Mailboxes.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/dmaas/powershell/protectDmaasM365Mailboxes) [`Update`] added support for security groups
* [smbFileOpens](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/smbFileOpens) [`Update`] added path filter

## 2024-01-18

* [legalHoldList.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/legalHoldList) [`Update`] moderized authentication

## 2024-01-17

* [restoreSQLv2.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/sql/restoreSQLv2) [`Fix`] added validation of target instance name

## 2024-01-16

* [protectVMsByTag.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/protectVMsByTag) [`Update`] added -noStorageDomain option to support NextGen Cloud Edition

## 2024-01-14

* [cohesity-api.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api) [`Update`] integrated legacy access modes
* [pyhesity.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/pyhesity) [`Update`] integrated legacy access modes

## 2024-01-13

* [detachWindowsAgent.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/detachWindowsAgent) [`New`] detach Windows agent from its Cohesity cluster
* [pauseProtectionActivity.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/pauseProtectionActivity) [`Update`] added pause/resume of indexing
* [slaStatus.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/slaStatus) [`Update`] modernized authentication and updated time range parameters
* [registerADSource.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/registerADSource) [`New`] register and Active Directory protection source

## 2024-01-11

* [cloneDirectory.sh](https://github.com/bseltz-cohesity/scripts/tree/master/bash/cloneDirectory) [`New`] clone a directory using bash

## 2024-01-08

* [storagePerObjectReport.ps1](https://github.com/bseltz-cohesity/scripts/tree/master/reports/powershell/storagePerObjectReport) [`Update`] Added multi-cluster support
* [storagePerObjectReport.py](https://github.com/bseltz-cohesity/scripts/tree/master/reports/python/storagePerObjectReport) [`Update`] Added multi-cluster support

## 2024-01-05

* [legalHold.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/legalHold) [`New`] Add/Remove legal hold from specified protection run
* [changeLocalRetention.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/changeLocalRetention) [`Update`] added options to select specific run for retention change

## 2024-01-03

* [detachLinuxAgent](https://github.com/bseltz-cohesity/scripts/tree/master/linux/detachLinuxAgent) (linux) [`New`] detach linux agent from cluster via SSH
* [detachLinuxAgent.exe](https://github.com/bseltz-cohesity/scripts/tree/master/windows/detachLinuxAgent) (windows) [`New`] detach linux agent from cluster via SSH
* [detachLinuxAgent.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/detachLinuxAgent) (python) [`New`] detach linux agent from cluster via SSH

## 2024-01-02

* [scheduleHealer.py](https://github.com/bseltz-cohesity/scripts/tree/master/python/scheduleHealer) [`New`] schedule an Apollo healer run
