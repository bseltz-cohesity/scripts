# Clone Multiple SQL DBs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform a SQL Clone Attach using PowerShell. The script takes a thin-provisioned clone of the latest backup of a SQL database and attaches it to a SQL server.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneSQLDBs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneSQLDBs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/cloneSQLDBs/cloneSQLDBs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneSQLDBs.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -sourceServer sqlprod.mydomain.net `
                  -sourceDB CohesityDB `
                  -targetServer sqldev.mydomain.net `
                  -suffix '-Dev' `
                  -logTime '2019-06-30 04:30:55' `
                  -wait
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
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -sourceServer: source SQL Server Name
* -sourceDB: (optional) one or more source database names (comma separated)
* -sourceDBList: (optional) text file of database names (one per line)
* -targetServer: (optional) SQL Server to attach clone to, defaults to same as sourceServer
* -prefix: (optional) prefix to apply to target database names
* -suffix: (optional) suffix to apply to target database names
* -targetInstance: (optional) name of SQL instance on targetServer (defaults to MSSQLSERVER)
* -logTime: (optional) point in time to replay the logs to (if omitted will default to time of latest DB backup)
* -noLogs: (optional) do not replay any logs
* -latest: (optional) replay the logs to the latest point in time available
* -dbg: (optional) output API payload and exit

To specify a source instance, include the instance name in the sourceDB name, like MYINSTANCE/MyDB

## Always On Availability Groups

Use the **AAG name** as the **-sourceServer** when cloning from an AAG backup (e.g. -sourceServer myAAG1)
