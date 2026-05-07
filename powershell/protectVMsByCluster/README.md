# Protect VMware VMs by vSphere Cluster using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script auto-protects VMs by vSphere cluster, adding to a new or existing protection group.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectVMsByCluster'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectVMsByCluster.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectVMsByCluster/protectVMsByCluster.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

To create a new protection job:

```powershell
# example
./protectVMsByCluster.ps1 -vip mycluster `
                          -userName myuser `
                          -domain mydomain.net `
                          -vCenterName myvcenter.mydomain.net `
                          -dataCenter myDC `
                          -computeResource vSphereCluster1 `
                          -jobName 'my vm job' `
                          -policyName mypolicy
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Mandatory Parameters

* -jobName: name of protection job to create or add to
* -vCenterName: name of registered vCenter source
* -dataCenter: name of vSphere data center
* -computeResource: name of vSphere HA cluster or ESXi host

## Optional Parameters for New Jobs Only

* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)
* -appConsistent: (optional) quiesce VMs during backup
* -noStorageeDomain: (optional) do not specify storage domain (for CAD and NGCE deployments)

## Column Definitions for Output File (`protectionRunsReport-<date>.csv`)

| # | Column Header | Description |
| --- | --- | --- |
| A | **Start Time** | The start time of the object's backup snapshot (`yyyy-MM-dd HH:mm:ss`) |
| B | **End Time** | The end time of the object's backup snapshot (`yyyy-MM-dd HH:mm:ss`) |
| C | **Duration** | Total duration of the backup in seconds |
| D | **status** | Snapshot status of the object (e.g. `kSuccess`, `kFailed`) |
| E | **slaStatus** | Whether the SLA was `Met` or `Missed` for this run |
| F | **snapshotStatus** | Snapshot availability status — always `Active` for non-deleted snapshots |
| G | **objectName** | Name of the protected object (VM, database, host, etc.) |
| H | **sourceName** | Name of the registered protection source the object belongs to |
| I | **groupName** | Name of the protection group (backup job) |
| J | **policyName** | Name of the protection policy applied to the group |
| K | **Object Type** | Environment/workload type (e.g. `kVMware`, `kSQL`, `kOracle`, `kPhysical`) |
| L | **backupType** | Type of backup run (e.g. `kFull`, `kIncremental`, `kLog`) |
| M | **System Name** | Name of the Cohesity cluster that performed the backup |
| N | **Logical Size \<unit\>** | Logical size of the backed-up object in the chosen unit (default: GiB) |
| O | **Data Read \<unit\>** | Amount of data read from the source during backup, in the chosen unit |
| P | **Data Written \<unit\>** | Amount of data written to the Cohesity cluster during backup, in the chosen unit |
| Q | **Organization Name** | Tenant/organization name associated with the protection group |
| R | **DataLock Expiry** | Expiry date/time of a DataLock (Compliance mode WORM lock), if applicable |
| S | **Legal Hold** | Whether the snapshot is under legal hold (`True` / `False`) |
| T | **Snapshot Expiry** | The date/time when the snapshot is scheduled to expire |
