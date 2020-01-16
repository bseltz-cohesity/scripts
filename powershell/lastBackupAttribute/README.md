# Email Backup Strike Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates a vSphere custom attribute with the last successful backup date/time per VM.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'lastBackupAttribute'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* lastBackupAttribute.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./lastBackupAttribute.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -viServer vcenter.mydomain.net `
                 -viUser 'administrator@vsphere.local'
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -viServer: vCenter to connect to
* -viUser: vCenter user name
* -attributeName: name of custom attribute to use (defaults to 'Last Cohesity Backup')
