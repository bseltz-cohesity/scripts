# Unprotect Missing O365 Sharepoint Sites using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script removes missing Sharepoint sites from an O365 protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectMissingSharepointSites'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectMissingSharepointSites.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectMissingSharepointSites/unprotectMissingSharepointSites.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# example
./unprotectMissingSharepointSites.ps1 -vip mycluster `
                                      -username myuser `
                                      -domain mydomain.net `
                                      -sourceName myaccount.onmicrosoft.com `
                                      -jobname 'My O365 Sharepoint Job' `
                                      -sitesToRemove 999999
# end example
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -password: (optional) password (default is prompt or use cached password)
* -sourceName: name of registered O365 protection source
* -jobname: name of protection job to remove sites from
* -sitesToRemove: (optional) number of sites to remove (default is 99999)
