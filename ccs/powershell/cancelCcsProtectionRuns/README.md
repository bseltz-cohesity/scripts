# Cancel Ccs Protection Runs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script cancels all running protection activities.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cancelCcsProtectionRuns'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cancelCcsProtectionRuns.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/cancelCcsProtectionRuns/cancelCcsProtectionRuns.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# cancel all protection runs in a region
./cancelCcsProtectionRuns.ps1 -region us-east-2

# cancel a protection run for a specific VM
./cancelCcsProtectionRuns.ps1 -region us-west-2 -sourceName myvcenter.mydomain.com -objectName myVM1
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -region: Ccs region to use (e.g. us-east-2)
* -environment: (optional) e.g. kO365
* -subType: (optional) e.g. kO365Sharepoint
* -sourceName: (optional) e.g. name of registered source
* -objectName: (optional) e.g. name of virtual machine

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
