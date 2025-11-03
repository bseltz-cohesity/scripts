# Find Object UUIDs in Helios using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script searches for an object by name and displays its global Uuid.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosObjectUuid'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [heliosObjectUuid.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/heliosObjectUuid/heliosObjectUuid.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./heliosObjectUuid.ps1 -objectName myobject
```

## Parameters

* -vip: (optional) Helios SaaS or Helios On-Prem address (Default is helios.cohesity.com)
* -clusterNames: (optional) comma seaparated list of clusters (default is all clusters)
* -username: (optional) name of user to connect to Helios (only used for password storage)
* -objectName: name of object to search for
* -fuzzySearch: (optional) include objects where the specified objectName is a substring of the objectName

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -username myusername@mydomain.net -updatePassword
Enter your password: *********************
```
