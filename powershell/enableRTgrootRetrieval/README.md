# Enable Remote Groot Export Retrieval using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will enable RT (remote support channel) and export the information needed for Cohesity support to retrieve an export of the custom reporting database. The support channel will close after the number of days specified.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'enableRTgrootRetrieval'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* enableRTgrootRetrieval: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./enableRTgrootRetrieval.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -days 1
```

Send the text output of the script to your Cohesity support representative. They can then use the information to collect the database export.

If you want to close the support channel immediately:

```powershell
./enableRTgrootRetrieval.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -disable
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -days: (optional) number of days to leave the support channel open (default is 1)
* -disable: (optional) close the support channel now
