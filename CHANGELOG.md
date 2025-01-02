# Change Log for cohesity/community-automation-samples

## 2024-12-31

* [cohesity-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api) [`Update`] added `heliosCluster -` to switch back to global context

## 2024-12-29

* [deploySaasSites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/deploySaasSites) [`New`] Wrapper script to deploy a SaaS Site in CCS (deploy a SaaS Connector, register and protect an ESXi Host)

## 2024-12-26

* [protectCcsVms.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/protectCcsVMs) [`New`] protect VMware VMs in CCS

## 2024-12-25 🎄

* [registerVCenterCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/registerVCenterCCS) [`New`] register a vCenter in CCS
* [registerESXiHostCCS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/registerESXiHostCCS) [`New`] register an ESXi host in CCS

## 2024-12-24

* [manageSaaSTrafficRoutes](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/manageSaaSTrafficRoutes) [`New`] manage SaaS Connector VMware traffic routing using PowerShell

## 2024-12-23

* [restoreSQLv2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/restoreSQLv2) [`Update`] added -noLogs parameter
* [manageSaaSConnectorGroups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/manageSaaSConnectorGroups) [`New`] manage SaaS Connector groups using PowerShell

## 2024-12-22

* [deploySaaSConnector.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/deploySaaSConnector) [`New`] deploy and register SaaS Connector OVA using PowerShell

## 2024-12-20

* [backupNowCcs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/ccs/powershell/backupNowCcs) [`Update`] Added password parameter

## 2024-12-17

* [gflagList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/gflagList) [`New`] list available gflags for the specified service

## 2024-12-16

* [protectGenericNas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectGenericNas) [`Update`] updated to use the V2 API

## 2024-12-12

* [protectUDA.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectUDA) [`Update`] added support for existing jobs

* [replicateOldSnapshotsV2.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replicateOldSnapshotsV2) [`New`] replicate old snapshots using the V2 API
* [legalHoldObject.py](https://github.com/cohesity/community-automation-samples/tree/main/python/legalHoldObject) [`New`] set legal hold per object across a range of dates

## 2024-12-10

* [validateServerBackup.py](https://github.com/cohesity/community-automation-samples/tree/main/python/validateServerBackup) [`New`] validate server backups

## 2024-12-09

* [replicationReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/replicationReport) [`New`] generate a replication report using Python

## 2024-12-08

* [cloneOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/cloneOracle) [`Update`] added -pfileList parameter
* [restoreOracle-v2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle-v2) [`Update`] added -pfileList parameter
* [restoreOracle.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracle) [`Update`] added -pfileList parameter

## 2024-12-07

* [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Update`] added -pl (--pfilelist) parameter
* [restoreOracle-v2.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle-v2) [`Update`] added -pl (--pfilelist) parameter
* [restoreOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracle) [`Update`] added -pl (--pfilelist) parameter

## 2024-12-06

* [downloadM365Files.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadM365Files) [`New`] download files from M365 OneDrive and Sharepoint

## 2024-12-05

* [registerVcenter.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerVcenter) [`Update`] added support for networks for data transfer

## 2024-12-04

* [cloneSQL.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/cloneSQL) [`Update`] added -noLogs parameter
* [cloneSQLDBs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/sql/powershell/cloneSQLDBs) [`Update`] added -noLogs parameter

## 2024-12-03

* [cloneOracle.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/cloneOracle) [`Fix`] fixed channel node selection

## 2024-12-02

* [destroyClone.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/destroyClone) [`Updated`] added support for multiple DB names
* [registerSQL.py](https://github.com/cohesity/community-automation-samples/tree/main/sql/python/registerSQL) [`Updated`] modernized authentication

## 2024-12-01

* [restoreOracleLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/oracle/python/restoreOracleLogs) [`New`] restore oracle archive logs
* [restoreOracleLogs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/oracle/powershell/restoreOracleLogs) [`New`] restore oracle archive logs

## Old Change Logs

* [CHANGELOG 2024](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
* [CHANGELOG 2023](https://github.com/cohesity/community-automation-samples/tree/main/Old-CHANGELOG-2024.md)
