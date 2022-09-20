# Protect VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds VMs to a new or existing protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectVM'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* protectVM.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectVM.ps1 -vip mycluster -username admin -jobName 'vm backup' -vmName mongodb
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -vmName: one or more VMs to add to the proctection job (comma separated)
* -vmList: file containing list of VMs to add (one per line)
* -jobName: name of protection job

## Optional Parameters

* -vCenterName: (optional) name of registered vCenter source (required for new job)
* -policyName: (optional) name of the protection policy to use (required for new job)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD, kBackupSSD, or kBackupAll (default is kBackupHDD)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)
* -includeFirstDiskOnly: (optional) exclude all but the first disk
* -includeDisk: (optional) one or more disks to include (comma separated), e.g. 0:1, 0:2
* -excludeDisk: (optional) one of more disks to exclude (comma separated), e.g. 0:1, 0:2
