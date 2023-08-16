# Wrapper to Clone Backups to Views for All Jobs that Match a String

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to clone backups to views for all jobs matching a string.

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cbtvWrapper'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'cloneBackupToView'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* cbtvWrapper.ps1: the main wrapper powershell script
* cloneBackupToView.ps1: the cloning script
* cohesity-api.ps1: the Cohesity REST API helper module

## Example

```powershell
.\cbtvWrapper.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -jobString sql
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -useApiKey: (optional) use API key for authentication
* -password: (optional) password or API key (will use stored password by default)
* -jobString: search string to identify jobs

For cloneBackupToView parameters, see here <https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cloneBackupToView>
