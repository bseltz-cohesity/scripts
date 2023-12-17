# Get Protection Status for an Object Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script shows the protection status for an object.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'objectProtectionStatus'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [objectProtectionStatus.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/objectProtectionStatus/objectProtectionStatus.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./objectProtectionDetails.ps1 -vip mycluster `
                              -username myusername `
                              -domain mydomain.net `
                              -object myserver.mydomain.net `
                              -dbname mydatabase
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -object: object name to report
* -dbname: (optional) name of database to report
