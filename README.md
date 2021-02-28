# Cohesity REST API Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Contents

* [PowerShell](#powershell)
  * [Reporting](#powershell-reporting)
  * [Cluster Configuration](#powershell-dataprotect-clusterconfig)
  * [Data Protection](#powershell-dataprotect)
    * [Files and Folders](#powershell-dataprotect-files)
    * [Databases](#powershell-dataprotect-db)
    * [Physical Servers](#powershell-dataprotect-physical)
    * [Virtual Machines](#powershell-dataprotect-vm)
    * [NAS](#powershell-dataprotect-nas)
    * [Other](#powershell-dataprotect-other)
    * [Agents](#powershell-agents)
    * [Archival](#powershell-archival)
    * [Replication](#powershell-replication)
    * [Manage Retention](#powershell-retention)
    * [Other Cleanup](#powershell-cleanup)
  * [Ransomware and Compliance](#powershell-compliance)
  * [SmartFiles](#powershell-smartfiles)
  * [Test/Dev](#powershell-testdev)
* [Python](#python)
  * [Cluster Configuration](#python-clusterconfig)
  * [Data Protection](#python-dataprotect)
    * [Files and Folders](#python-dataprotect-files)
    * [Databases](#python-dataprotect-db)
    * [Physical Servers](#python-dataprotect-physical)
    * [Virtual Machines](#python-dataprotect-vm)
    * [NAS](#python-dataprotect-nas)
    * [Other](#python-dataprotect-other)
    * [Archival](#python-archival)
    * [Replication](#python-replication)
    * [Manage Retention](#python-changeretention)
  * [SmartFiles](#python-smartfiles)
  * [Test/Dev](#python-testdev)

## PowerShell <a name="powershell"/>

* Help running Cohesity PowerShell Scripts: [Running Cohesity PowerShell Scripts.pdf](./powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf)

### Reporting <a name="powershell-reporting"/>

* Capacity Report Gallery: [Capacity Report Gallery](./capacityTools/README.md)
* Data Protection Report Gallery: [Protection Report Gallery](./powershell/PowerShell%20Protection%20Reports.md)

### Cluster Configuration <a name="powershell-dataprotect-clusterconfig"/>

* Join Active Directory: [addActiveDirectory](./powershell/addActiveDirectory)
* Create and Configure Virtual Cluster: [clusterCreateAndConfigVE](./powershell/clusterCreateAndConfigVE)
* Deploy Single-node (robo) Virtual Edition: [deployVE](./powershell/deployVE)
* Deploy Clustered Virtual Edition: [deployCVE](./powershell/deployCVE)
* Custom Host Mappings: [addCustomHostMapping](./powershell/addCustomHostMapping)
* Add a VLAN: [addVlan](./powershell/addVlan)
* Add Object to User Access List: [addObjectToUserAccessList](./powershell/addObjectToUserAccessList)
* Clone a Role: [cloneRole](./powershell/cloneRole)

### Data Protection <a name="powershell-dataprotect"/>

#### Files and Folders <a name="powershell-dataprotect-files"/>

* Restore Files and Folders (Physical): [restoreFiles](./powershell/restoreFiles)
* Restore Files and Folders (VM): [restoreVMFiles](./powershell/restoreVMFiles)
* List Backed Up Files: [backedUpFieList](./powershell/backedUpFileList)
* Download a File: [downloadFile](./powershell/downloadFile)

#### Databases <a name="powershell-dataprotect-db"/>

* Register Oracle Source (Physical): [registerOracle](./powershell/registerOracle)
* Protect Oracle Database: [protectOracle](./oracle/powershell/protectOracle)
* Restore Oracle Databse: [restoreOracle](./powershell/restoreOracle)
* Register a SQL Source (Physical): [registerSQL](./powershell/registerSQL)
* Register a SQL Source (VM): [registerSQLVM](./powershell/registerSQLVM)
* Protect SQL Database: [protectSQLDB](./powershell/protectSQLDB)
* Restore SQL Database: [restoreSQL](./powershell/restoreSQL)
* Restore SQL Server: [restoreSQLDBs](./powershell/restoreSQLDBs)

#### Physical Servers <a name="powershell-dataprotect-physical"/>

* Register a Physical Protection Source: [registerPhysical](./powershell/registerPhysical)
* Add a Server to a Volume-based Protection Group: [addPhysicalToProtectionJob](./powershell/addPhysicalToProtectionJob)
* Add Linux/Aix Servers to a File-based Protection Group: [protectLinux](./powershell/protectLinux)
* Add Windows Servers to a File-based Protection Group: [protectWindows](./powershell/protectWindows)

#### Virtual Machines <a name="powershell-dataprotect-vm"/>

* Register a vCenter Source: [registerVcenter](./powershell/registerVcenter)
* Add a VM to a Protection Group: [addVMtoProtectionJob](./powershell/addVMtoProtectionJob)
* AutoProtect GCP VMs: [autoProtectGcpVms](./powershell/autoProtectGcpVms)
* Create a VM Protection Group: [createVMProtectionJob](./powershell/createVMProtectionJob)
* Set Last Backup Attribute in VMware: [lastBackupAttribute](./powershell/lastBackupAttribute)
* Protect a VM: [protectVM](./powershell/protectVM)
* Recover a VM: [recoverVM](./powershell/recoverVM)
* Restore VMs: [restoreVMs](./powershell/restoreVMs)

#### NAS <a name="powershell-dataprotect-nas"/>

* Protect Generic NAS Mountpoints: [protectGenericNas](./powershell/protectGenericNas)
* Protect Isilon Shares: [protectIsilonShares](./powershell/protectIsilonShares)
* Protect Netapp: [protectNetapp](./powershell/protectNetapp)
* Recover a Nas Volume: [recoverNAS](./powershell/recoverNAS)
* Register Generic NAS Mountpoints: [registerGenericNasList](./powershell/registerGenericNasList)

#### Other <a name="powershell-dataprotect-other"/>

* Protect Remote Adapter: [protectRemoteAdapter](./powershell/protectRemoteAdapter)
* Instant Volume Mount: [instanceVolumeMount](./powershell/instantVolumeMount)
* Backup Now: [backupNow](./powershell/backupNow)
* Manage Job Alert Recipients: [jobAlertRecipients](./powershell/jobAlertRecipients)
* Refresh a Protection Source: [refreshSource](./powershell/refreshSource)
* Restore Active Directory Objects: [restoreADobjects](./powershell/restoreADobjects)
* Restore AWS EC2 VM: [restoreEC2VM](./powershell/restoreEC2VM)
* Restore Pure FlashArray Volumes: [restorePureVolumes](./powershell/restorePureVolumes)

#### Cohesity Agents <a name="powershell-agents"/>

* Deploy Windows Agents: [deployWindowsAgent](./powershell/deployWindowsAgent)
* List Agent Versions: [agentVersions](./powershell/agentVersions)

#### Archival <a name="powershell-archival"/>

* List Archived Objects: [archivedObjects](./powershell/archivedObjects)
* Archive Existing Snapshots: [archiveNow](./powershell/archiveNow)
* Archive Existing Snapshots (latest): [archiveNow-latest](./powershell/archiveNow-latest)
* Archive Old Snapshots: [archiveOldSnapshots](./powershell/archiveOldSnapshots)
* List Queued Archive Tasks: [archiveQueue](./powershell/archiveQueue)
* Cloud Archive Direct Stats: [cloudArchiveDirectStats](./powershell/cloudArchiveDirectStats)
* Monitor Archive Tasks: [monitorArchiveTasks](./powershell/monitorArchiveTasks)

#### Replication <a name="powershell-replication"/>

* Add a Replication Partnership: [addRemoteCluster](./powershell/addRemoteCluster)
* Monitor Replication Tasks: [monitorReplicationTasks](./powershell/monitorReplicationTasks)
* List Queued Replication Tasks: [replicacationQueue](./powershell/replicationQueue)
* Replicate Old Snapshots: [replicateOldSnapshots](./powershell/replicateOldSnapshots)

#### Change Retention <a name="powershell-retention"/>

* Change Local Retention: [changeLocalRetention](./powershell/changeLocalRetention)
* Expire Archived Snapshots: [expireArchivedSnapshots](./powershell/expireArchivedSnapshots)
* Expire Old Archives: [expireOldArchives](./powershell/expireOldArchives)
* Expire Old Snapshots: [expireOldSnaps](./powershell/expireOldSnaps)
* Expire Old Snapshots: and Reduce Retention [expireOldSnapsAndReduceRetention](./powershell/expireOldSnapsAndReduceRetention)

#### Other Clean Up <a name="powershell-cleanup"/>

* Expunge Data Spillage: [expungeDataSpillage](./powershell/expungeDataSpillage)
* Expunge VM Backups: [expungeVM](./powershell/exxpungeVM)

### Ransomware and Compliance <a name="powershell-compliance"/>

* Extension Finder: [extensionFinder](./powershell/extensionFinder)
* Manage Legal Hold: [legalHold](./powershell/legalHold)

### SmartFiles <a name="powershell-smartfiles"/>

* Clone a View: [cloneView](./powershell/cloneView)
* Create an NFS View: [createNfsView](./powershell/createNfsView)
* Create an SMB View: [createSMBView](./powershell/createSMBView)
* Set Directory Quotas: [directoryQuota](./powershell/directoryQuota)
* Protect a View: [protectView](./powershell/protectView)
* Disaster Recoery: [viewDR](./powershell/viewDR)

### Test/Dev <a name="powershell-testdev"/>

* List Existing Clones: [cloneList](./powershell/cloneList)
* Clone an Oracle Database: [cloneOracle](./oracle/powershell/cloneOracle)
* Clone a SQL Database: [cloneSQL](./sql-scripts/cloneSQL)
* Clone SQL Backup Files: [cloneSQLbackup](./sql-scripts/cloneSQLbackup)
* Clone a VM: [cloneVM](./powershell/cloneVM)
* Tear Down a Clone: [destroyClone](./powershell/destroyClone)

## Python <a name="python"/>

### Cluster Configuration <a name="python-clusterconfig"/>

* Cluster Create: [clusterCreate](./python/clusterCreate)
* Cluster Info Report: [clusterInfo](./python/clusterInfo)
* Deploy Clustered Virtual Edition: [deployCVE](./python/deployCVE)
* Add a Cluster Node: [nodeAdd](./python/nodeAdd)
* Remove a Cluster Node: [nodeRemove](./python/nodeRemove)
* Start Cluster: [startCluster](./python/startCluster)
* Stop Cluster: [stopCluster](./python/stopCluster)
* Upload SSL Certificate: [uploadSSLCertificate](./python/uploadSSLCertificate)

### Data Protection <a name="python-dataprotect"/>

#### Files and Folders <a name="python-dataprotect-files"/>

* List Backed Up Files: [backedUpFileList](./python/backedUpFileList)
* Download a File: [downloadFile](./python/downloadFile)
* Restore Fils and Folders: [restoreFiles](./python/restoreFiles)
* Restore NAS Files: [restoreNASFiles](./python/restoreNASFiles)
* Restore VM Files: [restoreVMFiles](./python/restoreVMFiles)

#### Databases <a name="python-dataprotect-db"/>

* Protect an Oracle Database: [protectOracle](./python/protectOracle)
* Restore an Oracle Database: [restoreOracle](./python/restoreOracle)
* Update Oracle DB Source Credentials: [updateOracleDbCredentials](./python/updateOracleDbCredentials)

#### Physical Servers <a name="python-dataprotect-physical"/>

* Register Physical Server: [registerPhysical](./python/registerPhysical)
* Protect Linux/AIX Servers: [protectLinux](./python/protectLinux)

#### Virtual Machines <a name="python-dataprotect-vm"/>

* Protect a VM: [protectVM](./python/protectVM)
* Mass VM Restore: [massVMrestore](./python/massVMrestore)
* Recover a VM: [recoverVM](./python/recoverVM)
* Restore VM Files: [restoreVMFiles](./python/restoreVMFiles)
* Update vCenter Source Credentials: [updateVcenterCredentials](./python/updateVcenterCredentials)

#### NAS <a name="python-dataprotect-nas"/>

* Protect FlashBlade: [protectFlashblade](./python/protectFlashblade)
* Protect Generic NAS Mountpoints: [protectGenericNas](./python/protectGenericNas)
* Protect New NFS Mount: [protectNewNFSMount](./python/protectNewNFSMount)
* Recover a NAS Volume: [recoverNASVolume](./python/recoverNASVolume)
* Register Generic NAS Mountpoint: [registerGenericNas](./python/registerGenericNas)
* Restore NAS Files: [restoreNASFiles](./python/restoreNASFiles)
* Restore Pure FlashArray Volumes: [restorePureVolumes](./python/restorePureVolumes)
* Update NAS Source Credentials: [updateNasCredentials](./python/updateNasCredentials)

#### Other <a name="python-dataprotect-other"/>

* Backup Now: [backupNow](./python/backupNow)
* Instant Volume Mount: [instantVolumeMount](./python/instantVolumeMount)
* Pause/Resume Protection Groups: [pauseResumeJobs](./python/pauseResumeJobs)
* List Available Recovery Points: [recoveryPoints](./python/recoveryPoints)

#### Archival <a name="python-archival"/>

* Archive End of Month Snapshots [archiveEndOfMonth](./python/archiveEndOfMonth)
* Archive Snapshots [archiveNow](./python/archiveNow)
* List Queued Archive Tasks [archiveQueue](./python/archiveQueue)

#### Replication <a name="python-replication"/>

* List Queued Replication Tasks: [replicationQueue](./python/replicationQueue)

#### Change Retention <a name="python-changeretention"/>

* Expire Old Snapshots: [expireOldSnapshots](./python/expireOldSnapshots)
* Extend Snapshot Retention: [extendRetention](./python/extendRetention)

### SmartFiles <a name="python-smartfiles"/>

* Clone a View Directory: [cloneDirectory](./python/cloneDirectory)
* Clone a View: [cloneView](./python/cloneView)
* Create an SMB View: [createSMBView](./python/createSMBView)
* Delete a View: [deleteView](./python/deleteView)

### Test/Dev <a name="python-testdev"/>

* Clone an Oracle Database: [cloneOracle](./python/cloneOracle)
* Tear Down Clone: [destroyClone](./python/destroyClone)
