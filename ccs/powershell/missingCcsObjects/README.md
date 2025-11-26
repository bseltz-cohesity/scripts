# Unprotect Missing Ccs Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists or unprotects protected objects that are missing from a protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'missingCcsObjects'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [missingCcsObjects.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/missingCcsObjects/missingCcsObjects.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To list missing objects of a protection source:

```powershell
./missingCcsObjects.ps1 -sourceName mydomain.onmicrosoft.com
```

To unprotect missing objects:

```powershell
./missingCcsObjects.ps1 -sourceName mydomain.onmicrosoft.com -unprotect
```

To also delete existing snapshots:

```powershell
./missingCcsObjects.ps1 -sourceName mydomain.onmicrosoft.com -unprotect -deleteSnapshots
```

To filter on specific object types:

```powershell
./missingCcsObjects.ps1 -sourceName mydomain.onmicrosoft.com -unprotect -deleteSnapshots -objectType kTeam
```

## Parameters

* -username: (optional) used for password storage only (default is 'ccs')
* -sourceName: name of protection source
* -region: (optional) specify region ID (e.g. us-east-2)
* -objectType: (optional) filter on specific object type (e.g. kGroup)
* -unprotect: (optional) unprotect objects (otherwise just list them)
* -deleteSnapshots: (optional) delete existing snapshots when unprotecting
* -pageSize: (optional) limit number of objects returned pr page (default is 100)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
