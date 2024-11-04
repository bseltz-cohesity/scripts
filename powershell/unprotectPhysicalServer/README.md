# Unprotect a Physical Server using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script removes a server from physical protection jobs.

Note: if the server is the last remaining server in a protection job, the job will be deleted.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectPhysicalServer'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectPhysicalServer.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectPhysicalServer/unprotectPhysicalServer.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./unprotectPhysicalServer.ps1 -vip mycluster `
                              -username myusername `
                              -domain mydomain.net `
                              -servername myserver.mydomain.net
```

Note: server names must exactly match what is shown in protection sources.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -servername: (optional) comma separated list of server names to remove from jobs
* -serverlist: (optional) text file containing server names to remove from jobs
