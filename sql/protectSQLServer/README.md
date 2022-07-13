# Protect SQL Server using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds a SQL server to a new or existing SQL protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectSQLServer'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/sql/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* protectSQLServer.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

To create a new protection job:

```powershell
# example
./protectSQLServer.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -servername server1.mydomain.net `
                       -policyname 'My Policy' `
                       -jobname 'My New Job'
# end example
```

Or to update an existing job:

```powershell
# example
./protectSQLServer.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -servername server1.mydomain.net `
                       -jobname 'My Existing Job'
# end example
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -jobname: name of protection job
* -servername: (optional) name of one or more registered SQL servers to protect (comma seaparated)
* -serverList: (optional) text file of registered SQL servers to protect (one per line)

## Optional Prameters

* -backupType: (optional) File, Volume or VDI (default is File)
* -instanceName: (optional) one or more instance names to protect (comma separated)
* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalProtectionSlaTimeMins: (optional) default 60
* -fullProtectionSlaTimeMins: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain' (or 'Direct_Archive_Viewbox' for cloud archive direct jobs)
* -paused: (optional) pause new protection job
* -instancesOnly: (optional) auto protect existing instances but not the root of the server (so any new instances will not be protected)
* -systemDBsOnly: (optional) only protect system DBs (for all or specified instanceName(s))
* -numStreams: (optional) only applicable to VDI backups (default is 3)
* -withClause: (optional) only applicable to VDI backups (e.g. 'WITH Compression')
