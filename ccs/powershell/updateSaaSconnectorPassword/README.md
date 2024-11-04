# Update SaaS Connector Password using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates the admin password for a SaaS connector

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateSaaSconnectorPassword'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateSaaSconnectorPassword.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/updateSaaSconnectorPassword/updateSaaSconnectorPassword.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./updateSaaSconnectorPassword.ps1 -vip 10.1.1.1 -username admin
```

## Parameters

* -vip: name or IP of SaaS Connector to connect to
* -currentPassword: (optional) will be prompted if omitted
* -newPassword: (optional) will be prompted if omitted
* -confirmPassword: (optional) will be prompted if omitted
