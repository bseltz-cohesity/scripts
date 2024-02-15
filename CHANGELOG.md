# Change Log for bseltz-cohesity/scripts

## 2024-02-15

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
