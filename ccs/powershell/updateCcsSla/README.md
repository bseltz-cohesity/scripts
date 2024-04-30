# Update Ccs Protection SLA using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script updates the SLA settings of protected Ccs objects.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateCcsSla'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateCcsSla.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/updateCcsSla/updateCcsSla.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./updateCcsSla.ps1 -incrementalSlaMinutes 720 `
                     -fullSlaMinutes 720 `
                     -objectName myvm1, myvm2
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -objectName: (optional) one or more protected object names (comma separated)
* -objectList: (optional) text file of protected object names (one per line)
* -incrementalSlaMinutes: incremental SLA minutes (e.g. 1440)
* -fullSlaMinutes: full SLA minutes (e.g. 1440)
* -pageSize: (optional) limit number of objects returned per page (default is 1000)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
