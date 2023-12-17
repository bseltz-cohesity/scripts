# Restore DMaaS M365 Teams using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores DMaaS M365 Teams.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreDmaasM365Team'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/dmaas/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreDmaasM365Team.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/dmaas/powershell/restoreDmaasM365Team/restoreDmaasM365Team.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreDmaasM365Team.ps1 -teamName team1, team2
```

## Basic Parameters

* -username: (optional) used for password storage only (default is 'DMaaS')
* -teamName: (optional) one or more team names (comma separated)
* -teamList: (optional) text file of team names (one per line)
* -source: (optional) registered M365 protection source to restore from
* -pageSize: (optional) limit number of objects returned pr page (default is 1000)

## Alternate Location Parameters

* -targetSource: (optional) registered M365 protection source to restore to
* -targetTeam: (optional) target team to restore to
* -recoverDate: (optional) restore latest snashot on or before this date (default is latest backup)

## Authenticating to DMaaS

DMaaS uses an API key for authentication. To acquire an API key:

* log onto DMaaS
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a DMaaS compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
