# Cohesity REST API Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## PowerShell

* Help running Cohesity PowerShell Scripts: [Running Cohesity PowerShell Scripts.pdf](./powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf)

### Reporting

* Capacity Report Gallery: [Capacity Report Gallery](./capacityTools/README.md)
* Data Protection Report Gallery: [Protection Report Gallery](./powershell/PowerShell%20Protection%20Reports.md)

### Cluster Configuration

* Join Active Directory: [addActiveDirectory](./powershell/addActiveDirectory)
* Create and Configure Virtual Cluster: [clusterCreateAndConfigVE](./powershell/clusterCreateAndConfigVE)
* Deploy Single-node (robo) Virtual Edition: [deployVE](./powershell/deployVE)
* Deploy Clustered Virtual Edition [deployCVE](./powershell/deployCVE)
* Custom Host Mappings: [addCustomHostMapping](./powershell/addCustomHostMapping)
* Add a VLAN: [addVlan](./powershell/addVlan)
* Add Object to User Access List: [addObjectToUserAccessList](./powershell/addObjectToUserAccessList)
* Clone a Role: [cloneRole](./powershell/cloneRole)

### Data Protection

#### Files and Folders

* Restore Files and Folders (Physical): [restoreFiles](./powershell/restoreFiles)
* Restore Files and Folders (VM): [restoreVMFiles](./powershell/restoreVMFiles)

#### Databases

* Register Oracle Source (Physical): [registerOracle](./powershell/registerOracle)
* Protect Oracle Database: [protectOracle](./oracle/powershell/protectOracle)
* Restore Oracle Databse: [restoreOracle](./powershell/restoreOracle)
* Register a SQL Source (Physical): [registerSQL](./powershell/registerSQL)
* Register a SQL Source (VM): [registerSQLVM](./powershell/registerSQLVM)
* Protect SQL Database: [protectSQLDB](./powershell/protectSQLDB)
* Restore SQL Database: [restoreSQL](./powershell/restoreSQL)
* Restore SQL Server: [restoreSQLDBs](./powershell/restoreSQLDBs)

#### Physical Servers

* Register a Physical Protection Source: [registerPhysical](./powershell/registerPhysical)
* Add a Server to a Volume-based Protection Group: [addPhysicalToProtectionJob](./powershell/addPhysicalToProtectionJob)
* Add Linux/Aix Servers to a File-based Protection Group: [protectLinux](./powershell/protectLinux)
* Add Windows Servers to a File-based Protection Group: [protectWindows](./powershell/protectWindows)

#### Virtual Machines

* Register a vCenter Source: [registerVcenter](./powershell/registerVcenter)
* Add a VM to a Protection Group: [addVMtoProtectionJob](./powershell/addVMtoProtectionJob)
* AutoProtect GCP VMs: [autoProtectGcpVms](./powershell/autoProtectGcpVms)
* Create a VM Protection Group: [createVMProtectionJob](./powershell/createVMProtectionJob)
* Set Last Backup Attribute in VMware: [lastBackupAttribute](./powershell/lastBackupAttribute)
* Protect a VM: [protectVM](./powershell/protectVM)
* Recover a VM: [recoverVM](./powershell/recoverVM)
* Restore VMs: [restoreVMs](./powershell/restoreVMs)

#### NAS

* Protect Generic NAS Mountpoints: [protectGenericNas](./powershell/protectGenericNas)
* Protect Isilon Shares: [protectIsilonShares](./powershell/protectIsilonShares)
* Protect Netapp: [protectNetapp](./powershell/protectNetapp)
* Recover a Nas Volume: [recoverNAS](./powershell/recoverNAS)
* Register Generic NAS Mountpoints: [registerGenericNasList](./powershell/registerGenericNasList)

#### Other

* Protect Remote Adapter: [protectRemoteAdapter](./powershell/protectRemoteAdapter)
* List Backed Up Files: [backedUpFieList](./powershell/backedUpFileList)
* Download a File: [downloadFile](./powershell/downloadFile)
* Instant Volume Mount: [instanceVolumeMount](./powershell/instantVolumeMount)
* Backup Now: [backupNow](./powershell/backupNow)
* Manage Job Alert Recipients: [jobAlertRecipients](./powershell/jobAlertRecipients)
* Refresh a Protection Source: [refreshSource](./powershell/refreshSource)
* Restore Active Directory Objects: [restoreADobjects](./powershell/restoreADobjects)
* Restore AWS EC2 VM: [restoreEC2VM](./powershell/restoreEC2VM)
* Restore Pure FlashArray Volumes: [restorePureVolumes](./powershell/restorePureVolumes)

#### Cohesity Agents

* Deploy Windows Agents: [deployWindowsAgent](./powershell/deployWindowsAgent)
* List Agent Versions: [agentVersions](./powershell/agentVersions)

#### Archival

* List Archived Objects: [archivedObjects](./powershell/archivedObjects)
* Archive Existing Snapshots: [archiveNow](./powershell/archiveNow)
* Archive Existing Snapshots (latest): [archiveNow-latest](./powershell/archiveNow-latest)
* Archive Old Snapshots [archiveOldSnapshots](./powershell/archiveOldSnapshots)
* List Queued Archive Tasks [archiveQueue](./powershell/archiveQueue)
* Cloud Archive Direct Stats [cloudArchiveDirectStats](./powershell/cloudArchiveDirectStats)
* Monitor Archive Tasks: [monitorArchiveTasks](./powershell/monitorArchiveTasks)

#### Replication

* Add a Replication Partnership: [addRemoteCluster](./powershell/addRemoteCluster)
* Monitor Replication Tasks: [monitorReplicationTasks](./powershell/monitorReplicationTasks)
* List Queued Replication Tasks: [replicacationQueue](./powershell/replicationQueue)
* Replicate Old Snapshots: [replicateOldSnapshots](./powershell/replicateOldSnapshots)

#### Change Retention

* Change Local Retention: [changeLocalRetention](./powershell/changeLocalRetention)
* Expire Archived Snapshots: [expireArchivedSnapshots](./powershell/expireArchivedSnapshots)
* Expire Old Archives: [expireOldArchives](./powershell/expireOldArchives)
* Expire Old Snapshots: [expireOldSnaps](./powershell/expireOldSnaps)
* Expire Old Snapshots and Reduce Retention [expireOldSnapsAndReduceRetention](./powershell/expireOldSnapsAndReduceRetention)

#### Other Clean Up

* Expunge Data Spillage [expungeDataSpillage](./powershell/expungeDataSpillage)
* Expunge VM Backups [expungeVM](./powershell/exxpungeVM)

### Ransomware and Compliance

* Extension Finder: [extensionFinder](./powershell/extensionFinder)
* Manage Legal Hold [legalHold](./powershell/legalHold)

### SmartFiles

* Clone a View: [cloneView](./powershell/cloneView)
* Create an NFS View: [createNfsView](./powershell/createNfsView)
* Create an SMB View: [createSMBView](./powershell/createSMBView)
* Set Directory Quotas: [directoryQuota](./powershell/directoryQuota)
* Protect a View: [protectView](./powershell/protectView)
* Disaster Recoery: [viewDR](./powershell/viewDR)

### Test/Dev

* List Existing Clones: [cloneList](./powershell/cloneList)
* Clone an Oracle Database: [cloneOracle](./oracle/powershell/cloneOracle)
* Clone a SQL Database: [cloneSQL](./sql-scripts/cloneSQL)
* Clone SQL Backup Files [cloneSQLbackup](./sql-scripts/cloneSQLbackup)
* Clone a VM [cloneVM](./powershell/cloneVM)
* Tear Down a Clone [destroyClone](./powershell/destroyClone)
