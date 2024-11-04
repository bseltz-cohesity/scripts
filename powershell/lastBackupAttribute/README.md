# Update Last Cohesity Backup Custom Attribute in vSphere Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates a vSphere custom attribute with the last successful backup date/time per VM. Note that this script requires vSphere PowerCLI to be installed, and the vSphere version must support custom attributes.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'lastBackupAttribute'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [lastBackupAttribute.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/lastBackupAttribute/lastBackupAttribute.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

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
* -domain: (optional) Active Directory domain of user (defaults to local)
* -viServer: vCenter to connect to
* -viUser: vCenter user name
* -viPassword: vCenter password (will prompt and store password if omitted)
* -attributeName: (optional) name of custom attribute to use (defaults to 'Last Cohesity Backup')

## Notes

This script can be scheduled to run periodically using Windows task scheduler. For help, please review this guide: <https://github.com/cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
