# Protect CCS MS SQL Databases using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects CCS MS SQL servers, instances, availability groups (AAGs) and databases.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectCCSSQL'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectCCSSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/protectCCSSQL/protectCCSSQL.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Auto-protect an entire SQL server (all instances/databases):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -policyName Gold
```

Protect specific instances on one or more servers:

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net, sql2.mydomain.net `
                    -instanceNames MSSQLSERVER, INSTANCE2 `
                    -policyName Gold
```

Protect specific databases (defaults to the MSSQLSERVER instance if -instanceNames is omitted):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -dbNames AdventureWorks, Northwind `
                    -policyName Gold
```

`-dbNames` entries can optionally be qualified as `instanceName/dbName` to target a specific instance or AAG directly (this overrides `-instanceNames` for that entry, and can be mixed freely with unqualified names in the same list):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -dbNames 'INSTANCE2/AdventureWorks', 'AAG1/Northwind', Payroll `
                    -policyName Gold
```

Protect every database on a server (each database added individually rather than auto-protecting the server):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -allDBs `
                    -policyName Gold
```

Protect only the system databases (master, model, msdb):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -systemDBsOnly `
                    -policyName Gold
```

Auto-protect a server but exclude some databases by name (wildcard supported):

```powershell
./protectCCSSQL.ps1 -region us-east-2 `
                    -serverNames sql1.mydomain.net `
                    -policyName Gold `
                    -excludeDbNames TempReports, Staging*
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -password: (optional) will be prompted if omitted and not already stored
* -region: specify region (e.g. us-east-2)
* -policyName: name of protection policy to use
* -serverNames: (optional) one or more registered SQL server/host names to protect (comma separated)
* -serverList: (optional) text file of SQL server names to protect (one per line)
* -instanceNames: (optional) one or more SQL instance/AAG names to filter to (e.g. MSSQLSERVER)
* -dbNames: (optional) one or more database names to protect (comma separated). Each entry may be a short name (resolved against -instanceNames, or the default MSSQLSERVER instance if -instanceNames is omitted) or qualified as 'instanceName/dbName' to target a specific instance/AAG directly
* -dbList: (optional) text file of database names to protect (one per line, same 'instanceName/dbName' syntax supported)
* -excludeDbNames: (optional) one or more database name filters to exclude (wildcard supported, comma separated)
* -excludeDbList: (optional) text file of database name filters to exclude (one per line)
* -allDBs: (optional) protect every database found (within the selected servers/instances) as an individual object, rather than auto-protecting the server/instance as a whole
* -systemDBsOnly: (optional) protect only the system databases (master, model, msdb)
* -excludeSystemDbs: (optional) do not back up system databases when auto-protecting a server/instance
* -numStreams: (optional) number of streams for the native (VDI) backup (default 3)
* -withClause: (optional) T-SQL WITH clause for the native (VDI) backup
* -logBackupNumStreams: (optional) number of streams for log backups (default 3)
* -logBackupWithClause: (optional) T-SQL WITH clause for log backups
* -userDbBackupPreference: (optional) 'kBackupAllDatabases', 'kBackupAllExceptAAGDatabases', or 'kBackupOnlyAAGDatabases' (default is 'kBackupAllDatabases')
* -aagBackupPreference: (optional) 'kUseServerPreference', 'kPrimaryReplicaOnly', 'kSecondaryReplicaOnly', 'kPreferSecondaryReplica', or 'kAnyReplica' (default is 'kUseServerPreference')
* -fullBackupsCopyOnly: (optional) mark full backups as copy-only
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -pause: (optional) pause future runs
* -dbg: (optional) display JSON payload and exit

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
