# Protect SQL using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds a SQL server to a new or existing SQL protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectSQL'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/protectSQL/protectSQL.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

To create a new protection job:

```powershell
# example
./protectSQL.ps1 -vip mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -serverName server1.mydomain.net `
                 -policyName 'My Policy' `
                 -jobName 'My New Job'
# end example
```

Or to update an existing job:

```powershell
# example
./protectSQL.ps1 -vip mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -serverName server1.mydomain.net `
                 -jobName 'My Existing Job'
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Mandatory Parameters

* -jobname: name of protection job

## Selection Parameters

* -serverName: (optional) name of one or more registered SQL servers to protect (comma separated)
* -serverList: (optional) text file of registered SQL servers to protect (one per line)
* -instanceName: (optional) one or more instance names to protect (comma separated)
* -instancesOnly: (optional) auto protect existing instances but not the root of the server (so any instances added later will not be protected)
* -dbName: (optional) name of one or more databases to protect (comma separated)
* -dbList: (optional) text file of databases to protect (one per line)
* -systemDBsOnly: (optional) only protect system DBs (for all or specified instanceName(s))
* -unprotectedDBs: (optional) protect any unprotected databases on server
* -allDBs: (optional) protect all current databases (future new database will not be protected)
* -replace: (optional) replace existing selections

## New Job Parameters

* -backupType: (optional) File, Volume or VDI (default is File)
* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalProtectionSlaTimeMins: (optional) default 60
* -fullProtectionSlaTimeMins: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause new protection job

## Other Parameters

* -numStreams: (optional) only applicable to VDI backups (default is 3)
* -withClause: (optional) only applicable to VDI backups (e.g. 'WITH Compression')
* -logNumStreams: (optional) default is 3 (requires Cohesity 6.8.1 or later)
* -logWithClause: (optional) e.g. 'WITH MAXTRANSFERSIZE = 4194304, BUFFERCOUNT = 64, COMPRESSION' (requires Cohesity 6.8.1 or later)
* -sourceSideDeduplication: (optional) use source side deduplication
