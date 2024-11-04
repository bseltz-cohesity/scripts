# Protect O365 Sharepoint Sites using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script excludes protected Sharepoint sites from an autoprotect (catch-all) protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'excludeProtectedSharepointSites'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [excludeProtectedSharepointSites.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/excludeProtectedSharepointSites/excludeProtectedSharepointSites.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

First, create a "catch-all" job that autoprotects all Sharepoint sites. You can pause future runs if you don't want it to run at this time.

Place all files in a folder together. And run the script like so:

```powershell
# example
./excludeProtectedSharepointSites.ps1 -vip mycluster `
                                      -username myuser `
                                      -domain mydomain.net `
                                      -jobname 'My O365 Sharepoint Job'
# end example
```

The script will add exclusions to the job for sites that are protected by other jobs.

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -password: (optional) password (default is prompt or use cached password)
* -jobname: name of existing protection job to add sites to
