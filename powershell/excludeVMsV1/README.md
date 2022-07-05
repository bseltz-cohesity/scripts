# Exclude VMs froma Cohesity Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script excludes one or more VMs from an existing protection job where parent containers are autoprotected.

Note: This script is to be used with Cohesity versions prior to 6.5.1. For 6.5.1 or later, please use this version: <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/excludeVMs>

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'excludeVMsV1'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* excludeVMsV1.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./excludeVMsV1.ps1 -vip mycluster -username admin -jobName 'vm backup' -vmName mongodb
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -vmName: one or more VMs (comma separated) to add to the proctection job
* -vmList: file containing list of VMs to add
* -jobName: name of protection job
