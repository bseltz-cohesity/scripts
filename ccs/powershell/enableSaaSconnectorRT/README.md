# Enable Support Channel for SaaS Connector using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell enables/disavbles support channel for a SaaS connector

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'enableSaaSconnectorRT'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [enableSaaSconnectorRT.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/enableSaaSconnectorRT/enableSaaSconnectorRT.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./enableSaaSconnectorRT.ps1 -vip 10.1.1.1 -username admin -enable -days 5
```

or

```powershell
./enableSaaSconnectorRT.ps1 -vip 10.1.1.1 -username admin -disable
```

## Parameters

* -vip: name or IP of SaaS Connector to connect to
* -username: name of user to connect to SaaS connector
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -enable: (optional) enable support channel
* -disable: (optional) disable support channel
* -days: (optional) days to remain open (default is 1)
