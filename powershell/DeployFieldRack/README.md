# Field Rack Deployment Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a group of PowerShell scripts for deployment of a field rack.

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
./2-GoLive.ps1 -configFile ./config-rack1.ps1 -goLive -runNow
```

This phase will perform the following:

* Recover the VMs from  the Protection Job
* Create a protection policy with local and remote retentions (as per $daysToKeep)
* Create protection job to protect recovered VMs
* Pause the source protection job
* Extend retention of final source backup (as per $daysToKeepFinalBackup)
* Perform initial backup now (optional)

The VMs will now be running in the rack, protected by the Cohesity cluster in the rack, and replicating back to the local Cohesity cluster.