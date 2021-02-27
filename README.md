# Cohesity REST API Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## PowerShell

* Help running Cohesity PowerShell Scripts: [Running Cohesity PowerShell Scripts.pdf](./powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf)

### Reporting

* Capacity Report Gallery: [Capacity Report Gallery](./capacityTools/README.md)
* Data Protection Report Gallery: [Protection Report Gallery](./powershell/PowerShell%20Protection%20Reports.md)

### Cluster Configuration

* Join Active Directory: [addActiveDirectory.ps1](./powershell/addActiveDirectory)
* Create and Configure Virtual Cluster: [clusterCreateAndConfigVE](./powershell/clusterCreateAndConfigVE)
* Deploy Single-node (robo) Virtual Edition: [deployVE.ps1](./powershell/deployVE)
* Deploy Clustered Virtual Edition [deployCVE.ps1](./powershell/deployCVE)
* Custom Host Mappings: [addCustomHostMapping.ps1](./powershell/addCustomHostMapping)
* Add a VLAN: [addVlan.ps1](./powershell/addVlan)
* Add Object to User Access List: [addObjectToUserAccessList.ps1](./powershell/addObjectToUserAccessList)
* Clone a Role: [cloneRole.ps1](./powershell/cloneRole)

### Data Protection

#### Files and Folders

* Restore Files and Folders (Physical): [restoreFiles.ps1](./powershell/restoreFiles)
* Restore Files and Folders (VM): [restoreVMFiles.ps1](./powershell/restoreVMFiles)

#### Databases

* Register Oracle Source (Physical): [registerOracle.ps1](./powershell/registerOracle)
* Protect Oracle Database: [protectOracle.ps1](./oracle/powershell/protectOracle)
* Restore Oracle Databse: [restoreOracle.ps1](./powershell/restoreOracle)
* Register a SQL Source (Physical): [registerSQL.ps1](./powershell/registerSQL)
* Register a SQL Source (VM): [registerSQLVM.ps1](./powershell/registerSQLVM)
* Protect SQL Database: [protectSQLDB.ps1](./powershell/protectSQLDB)
* Restore SQL Database: [restoreSQL.ps1](./powershell/restoreSQL)
* Restore SQL Server: [restoreSQLDBs.ps1](./powershell/restoreSQLDBs)

#### Physical Servers

* Register a Physical Protection Source: [registerPhysical.ps1](./powershell/registerPhysical)
* Add a Server to a Volume-based Protection Group: [addPhysicalToProtectionJob.ps1](./powershell/addPhysicalToProtectionJob)
* Add Linux/Aix Servers to a File-based Protection Group: [protectLinux.ps1](./powershell/protectLinux)
* Add Windows Servers to a File-based Protection Group: [protectWindows.ps1](./powershell/protectWindows)

#### Virtual Machines

* Register a vCenter Source: [registerVcenter.ps1](./powershell/registerVcenter)
* Add a VM to a Protection Group: [addVMtoProtectionJob](./powershell/addVMtoProtectionJob)
* AutoProtect GCP VMs: [autoProtectGcpVms](./powershell/autoProtectGcpVms)
* Create a VM Protection Group: [createVMProtectionJob](./powershell/createVMProtectionJob)
* Set Last Backup Attribute in VMware: [lastBackupAttribute.ps1](./powershell/lastBackupAttribute)
* Protect a VM: [protectVM.ps1](./powershell/protectVM)
* Recover a VM: [recoverVM.ps1](./powershell/recoverVM)
* Restore VMs: [restoreVMs.ps1](./powershell/restoreVMs)

#### NAS

* Protect Generic NAS Mountpoints: [protectGenericNas.ps1](./powershell/protectGenericNas)
* Protect Isilon Shares: [protectIsilonShares.ps1](./powershell/protectIsilonShares)
* Protect Netapp: [protectNetapp.ps1](./powershell/protectNetapp)
* Recover a Nas Volume: [recoverNAS.ps1](./powershell/recoverNAS)
* Register Generic NAS Mountpoints: [registerGenericNasList.ps1](./powershell/registerGenericNasList)

#### Other

* Protect Remote Adapter: [protectRemoteAdapter.ps1](./powershell/protectRemoteAdapter)
* List Backed Up Files: [backedUpFieList.ps1](./powershell/backedUpFileList)
* Download a File: [downloadFile.ps1](./powershell/downloadFile)
* Instant Volume Mount: [instanceVolumeMount.ps1](./powershell/instantVolumeMount)
* Backup Now: [backupNow.ps1](./powershell/backupNow)
* Manage Job Alert Recipients: [jobAlertRecipients.ps1](./powershell/jobAlertRecipients)
* Refresh a Protection Source: [refreshSource.ps1](./powershell/refreshSource)
* Restore Active Directory Objects: [restoreADobjects.ps1](./powershell/restoreADobjects)
* Restore AWS EC2 VM: [restoreEC2VM.ps1](./powershell/restoreEC2VM)
* Restore Pure FlashArray Volumes: [restorePureVolumes.ps1](./powershell/restorePureVolumes)

#### Cohesity Agents

* Deploy Windows Agents: [deployWindowsAgent.ps1](./powershell/deployWindowsAgent)
* List Agent Versions: [agentVersions.ps1](./powershell/agentVersions)

#### Archival

* List Archived Objects: [archivedObjects.ps1](./powershell/archivedObjects)
* Archive Existing Snapshots: [archiveNow.ps1](./powershell/archiveNow)
* Archive Existing Snapshots (latest): [archiveNow-latest.ps1](./powershell/archiveNow-latest)
* Archive Old Snapshots [archiveOldSnapshots.ps1](./powershell/archiveOldSnapshots)
* List Queued Archive Tasks [archiveQueue.ps1](./powershell/archiveQueue)
* Cloud Archive Direct Stats [cloudArchiveDirectStats](./powershell/cloudArchiveDirectStats)
* Monitor Archive Tasks: [monitorArchiveTasks.ps1](./powershell/monitorArchiveTasks)

#### Replication

* Add a Replication Partnership: [addRemoteCluster.ps1](./powershell/addRemoteCluster)
* Monitor Replication Tasks: [monitorReplicationTasks.ps1](./powershell/monitorReplicationTasks)
* List Queued Replication Tasks: [replicacationQueue.ps1](./powershell/replicationQueue)
* Replicate Old Snapshots: [replicateOldSnapshots.ps1](./powershell/replicateOldSnapshots)

#### Change Retention

* Change Local Retention: [changeLocalRetention.ps1](./powershell/changeLocalRetention)
* Expire Archived Snapshots: [expireArchivedSnapshots.ps1](./powershell/expireArchivedSnapshots)
* Expire Old Archives: [expireOldArchives.ps1](./powershell/expireOldArchives)
* Expire Old Snapshots: [expireOldSnaps.ps1](./powershell/expireOldSnaps)
* Expire Old Snapshots and Reduce Retention [expireOldSnapsAndReduceRetention](./powershell/expireOldSnapsAndReduceRetention)

#### Other Clean Up

* Expunge Data Spillage [expungeDataSpillage](./powershell/expungeDataSpillage)
* Expunge VM Backups [expungeVM](./powershell/exxpungeVM)

### Ransomware and Compliance

* Extension Finder: [extensionFinder.ps1](./powershell/extensionFinder)
* Manage Legal Hold [legalHold.ps1](./powershell/legalHold)

### SmartFiles

* Clone a View: [cloneView](./powershell/cloneView)
* Create an NFS View: [createNfsView.ps1](./powershell/createNfsView)
* Create an SMB View: [createSMBView.ps1](./powershell/createSMBView)
* Set Directory Quotas: [directoryQuota.ps1](./powershell/directoryQuota)
* Protect a View: [protectView.ps1](./powershell/protectView)
* Disaster Recoery: [viewDR](./powershell/viewDR)

### Test/Dev

* List Existing Clones: [cloneList.ps1](./powershell/cloneList)
* Clone an Oracle Database: [cloneOracle.ps1](./oracle/powershell/cloneOracle)
* Clone a SQL Database: [cloneSQL.ps1](./sql-scripts/cloneSQL)
* Clone SQL Backup Files [cloneSQLbackup.ps1](./sql-scripts/cloneSQLbackup)
* Clone a VM [cloneVM.ps1](./powershell/cloneVM)
* Tear Down a Clone [destroyClone.ps1](./powershell/destroyClone)
