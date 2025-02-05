# Change Log for cohesity/community-automation-samples

## 2025-02-05

* [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) [`
Fix`] added pagination to file search
* [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) [`Fix`] added pagination to file search

## 2025-02-04

* [sqlProtectedObjectReport](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/sqlProtectedObjectReport) [`Update`] improved protectionSources query performance

## 2025-02-03

* [protectionRunsReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectionRunsReport) [`Update`] added job ID to output

## 2025-02-02

* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] modernized authentication
* [backedUpFSReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/backedUpFSReport) [`Update`] modernized authentication
* [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileFiles) [`Update`] modernized authentication

## 2025-01-31

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Fix`] fixed /v2/users/session authentication

## 2025-01-30

* [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) [`New`] report on VM recoveries

## 2025-01-27

* [updateCcsRdsCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/python/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [updateCcsRdsCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/updateCcsRdsCredentials) [`New`] update database credentials for RDS databases protected by CCS
* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added region parameter to api function

## 2025-01-23

* [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) [`Update`] Added CSV output and total folder size
* [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) [`Update`] Added CSV output and total folder size

## 2025-01-17

* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added -coe, --continueonerror option, -w, --wait option, updated folder enumeration

## 2025-01-16

* [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) [`Update`] added -env, --environment, -on, --objectname, -ol, --objectlist pre-filtering parameters

## 2025-01-15

* [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) [`Update`] added overwrite handaling

## 2025-01-14

* [vmRecoveryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/vmRecoveryReport) [`New`] report on VM recoveries
* [protectCcsM365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsM365Sites) [`Fix`] fixed issue with nested sites

## 2025-01-13

* [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/heliosV2/powershell/heliosCSVReport) [`Update`] added filters functionality

## 2025-01-10

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added `Get-Runs` function
* [archiveQueue.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/archiveQueue) [`Update`] updated to use the Get-Runs function
* [runningJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/runningJobs) [`Update`] updated to use the Get-Runs function
* [maintenance.py](https://github.com/cohesity/community-automation-samples/tree/main/python/maintenance) [`New`] set maintenance mode on protection sources

## 2025-01-08

* [pyhesity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pyhesity) [`Update`] added getRuns function

## 2025-01-07

* [expireOldArchives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expireOldArchives) [`Fix`] solved paging issue
* [fixRedundantProtection.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fixRedndantProtection) [`Update`] added filtering for M365
* [protectOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/protectOracle) [`Update`] added --noalert option

## 2025-01-02

* [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] added `-backupType` parameter

## Old Change Logs

* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2023.md)
