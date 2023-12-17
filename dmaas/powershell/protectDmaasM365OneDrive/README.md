# Protect DMaaS M365 OneDrives using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects DMaaS M365 OneDrives.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectDmaasM365OneDrive'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/dmaas/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectDmaasM365OneDrive.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/dmaas/powershell/protectDmaasM365OneDrive/protectDmaasM365OneDrive.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectDmaasM365OneDrive.ps1 -region us-east-2 `
                               -policyName Gold `
                               -sourceName mydomain.onmicrosoft.com `
                               -users user1.mydomain.onmicrosoft.com, user2.mydomain.onmicrosoft.com `
                               -userList ./userlist.txt
```

## Parameters

* -username: (optional) used for password storage only (default is 'DMaaS')
* -region: specify region (e.g. us-east-2)
* -sourceName: name of registered M365 protection source
* -policyName: name of protection policy to use
* -users: (optional) one or more user names or SMTP addresses (comma separated)
* -userList: (optional) text file of user names or SMTP addresses (one per line)
* -autoselect: (optional) protect first X unprotected one drives (unspecified)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -pageSize: (optional) limit number of objects returned pr page (default is 50000)

## Authenticating to DMaaS

DMaaS uses an API key for authentication. To acquire an API key:

* log onto DMaaS
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a DMaaS compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
