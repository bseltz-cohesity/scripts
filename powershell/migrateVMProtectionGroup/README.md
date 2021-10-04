# Migrate VM Protection Group using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script updates VMware protection jobs to remove missing VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateVMProtectionGroup'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* migrateVMProtectionGroup.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To update all VMware protection jobs:

```powershell
./migrateVMProtectionGroup.ps1 -sourceCluster myOldCluster `
                               -sourceUser myOldUsername `
                               -sourceDomain myOldDomain.net `
                               -targetCluster myNewCluster `
                               -targetUser myNewUsername `
                               -sourceDomain myNewDomain.net `
                               -jobName myjob
```

## Parameters

* -sourceCluster: name of source cluster to connect to
* -sourceUser: username for source cluster
* -sourceDomain: domain for source cluster user (defaults to local)
* -targetCluster: name of target cluster to connect to
* -targetUser: username for target cluster
* -targetDomain: domain for target cluster user (defaults to local)
* -jobName: name of job to migrate
