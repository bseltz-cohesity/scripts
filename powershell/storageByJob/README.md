# Report Job and View Storage Consumption Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports per job and per view storage consumption. The script relies on consumption metrics that were introduced in Cohesity version 6.4, so the script will not work with prior versions.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storageByJob'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* storageByJob.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
.\storageByJob.ps1 -vip mycluster -username myuser -domain mydomain.net
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
