# Field Rack Deployment Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a group of PowerShell scripts for deployment of a field rack.

## Download the scripts

Run the following commands from within PowerShell to download the scripts into the current folder:

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/1-BuildOut.ps1).content | Out-File 1-BuildOut.ps1; (Get-Content 1-BuildOut.ps1) | Set-Content 1-BuildOut.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/2-GoLive.ps1).content | Out-File 2-GoLive.ps1; (Get-Content 2-GoLive.ps1) | Set-Content 2-GoLive.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/addRemoteCluster.ps1).content | Out-File addRemoteCluster.ps1; (Get-Content addRemoteCluster.ps1) | Set-Content addRemoteCluster.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/backupRunNow.ps1).content | Out-File backupRunNow.ps1; (Get-Content backupRunNow.ps1) | Set-Content backupRunNow.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/cohesityCluster.ps1).content | Out-File cohesityCluster.ps1; (Get-Content cohesityCluster.ps1) | Set-Content cohesityCluster.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/config-rack1.ps1).content | Out-File config-rack1.ps1; (Get-Content config-rack1.ps1) | Set-Content config-rack1.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/createProtectionPolicy.ps1).content | Out-File createProtectionPolicy.ps1; (Get-Content createProtectionPolicy.ps1) | Set-Content createProtectionPolicy.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/createVMProtectionJob.ps1).content | Out-File createVMProtectionJob.ps1; (Get-Content createVMProtectionJob.ps1) | Set-Content createVMProtectionJob.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/extendRetention.ps1).content | Out-File extendRetention.ps1; (Get-Content extendRetention.ps1) | Set-Content extendRetention.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/pauseProtectionJob.ps1).content | Out-File pauseProtectionJob.ps1; (Get-Content pauseProtectionJob.ps1) | Set-Content pauseProtectionJob.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/deployFieldRack/recoverVMJob.ps1).content | Out-File recoverVMJob.ps1; (Get-Content recoverVMJob.ps1) | Set-Content recoverVMJob.ps1
# End download commands
```

## High-level Steps

* Create Configuration File for the rack
* Create VM List for the rack
* Execute 1-BuildOut.ps1
* Wait for final VM state, final backup and replication
* Execute 2-GoLive.ps1

## Configuration Files

The configuration file contains all the details of the local and remote Cohesity settings, for example:

```powershell
# config-rack1.ps1

### Global Settings
$daysToKeep = 5
$daysToKeepFinalBackup = 365
$startTime = '22:00'
$vmList = './rack1-vmlist.txt'

### Local Setup Info
$localClusterName = 'myLocalCluster'
$localVip = '192.168.1.198'
$localUsername = 'admin'
$localDomain = 'local'
$localStorageDomain = 'DefaultStorageDomain'

$localJobName = 'LocalToRack1'
$localPolicyName = 'LocalToRack1'

$localVCenter = 'vCenter6.seltzer.net'

### Remote Rack Info
$remoteClusterName = 'Rack1VE'
$remoteVip = '192.168.1.199'
$remoteUsername = 'admin'
$remoteDomain = 'local'
$remoteStorageDomain = 'DefaultStorageDomain'

$remoteJobName = 'Rack1VEToLocal'
$remotePolicyName = 'Rack1VEToLocal'

$remoteVCenter = 'vCenter6-B.seltzer.net'
$remoteDatastore = '450GB'
$remoteNetwork = 'VM Network'
$remoteResourcePool = 'Test' #optional
$remoteVMFolder = 'Test' #optional
```

Adjust these according to your environement. Also create a text file list of VMs that will be deployed into the rack:

```text
rack1DC01
rack1FS01
```

## BuildOut Phase

The VMs are initially build in the local vSphere environment. Once built, we can run 1-BuildOut.ps1 like so:

```powershell
./1-BuildOut.ps1 -configFile ./config-rack1.ps1 -runNow
```

This will perform the following steps:

* Establish replication between local and rack Cohesity clusters
* Create a Protection Policy with local and remote retentions (as per $daysToKeep)
* Create a Protection Job to backup and replicate the VMs
* Perform initial backup now (optional)

## Finalization Phase

Next we wait for VM configurations to be finalized and a final backup and replication to occur before moving on to the GoLive phase. 

**_Note: At this stage you will want to poweroff the VMs in the local vSphere environment._**

If you wish to run a final backup and replication on-demand, we can run the following:

```powershell
. ./config-rack1.ps1
./backupRunNow.ps1 -vip $localVip `
                   -username $localUsername `
                   -domain $localDomain `
                   -jobName $localJobName `
                   -daysToKeep $daysToKeep
```

## GoLive Phase

When the VM configurations have been finalized and the final backup has replicated to the rack, we can perform a curover to the rack, like so:

```powershell
./2-GoLive.ps1 -configFile ./config-rack1.ps1 -recover
```
This will recover the VMs to the rack. After that is complete, we can perform the final GoLive steps: 

```powershell
./2-GoLive.ps1 -configFile ./config-rack1.ps1 -goLive
```

This phase will perform the following:

* Create a protection policy with local and remote retentions (as per $daysToKeep)
* Create protection job to protect recovered VMs
* Pause the source protection job
* Extend retention of final source backup (as per $daysToKeepFinalBackup)
* Perform initial backup now (optional)

The VMs will now be running in the rack, protected by the Cohesity cluster in the rack, and replicating back to the local Cohesity cluster.