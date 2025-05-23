# Restore Ccs M365 Sharepoint Sites using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores Ccs M365 Sites.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreCcsM365Site'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreCcsM365Site.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/restoreCcsM365Site/restoreCcsM365Site.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreCcsM365Site.ps1 -siteName user1.mydomain.onmicrosoft.com, user2.mydomain.onmicrosoft.com
```

## Basic Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -siteName: (optional) one or more site names (comma separated)
* -siteList: (optional) text file of site names (one per line)
* -source: (optional) registered M365 protection source to restore from
* -pageSize: (optional) limit number of objects returned pr page (default is 1000)
* -useMBS:  (optional) use Microsoft 365 Backup Storage

## Alternate Location Parameters

* -targetSource: (optional) registered M365 protection source to restore to
* -recoverDate: (optional) restore latest snashot on or before this date (default is latest backup)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
