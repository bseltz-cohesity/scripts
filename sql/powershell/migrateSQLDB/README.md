# Migrate a SQL Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script initiates, syncs, finalizes or lists SQL database migrations.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateSQLDB'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateSQLDB.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/migrateSQLDB/migrateSQLDB.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Operating Modes

The script will list, initialize, sync or finalize migrations.

## List Mode

To list existing migrations in progress (On Hold or Running):

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net
```

To list existing migrations (including completed migrations):

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -showAll `
                   -daysBack 7
```

To list existing migrations for a specific source database:

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -sourceServer sqlserver1 `
                   -sourceDB MSSQLSERVER/mydb `
                   -showAll `
                   -daysBack 7
```

## Init Mode

To initiate a new migration:

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -sourceServer sqlserver1 `
                   -sourceDB MSSQLSERVER/mydb `
                   -targetServer sqlsserver2 `
                   -targetDB mydb2 `
                   -mdfFolder c:\sqldata 
```

## Sync Mode

To sync all existing migration(s):

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -sync
```

Or you can filter on name, id or filter:

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -sync `
                   -id -id 428418101664119:1631181117066:180265
```

## Finalize Mode

To finalize existing migration(s):

```powershell
./migrateSQLDB.ps1 -vip mycluster `
                   -username myuser `
                   -domain mydomain.net `
                   -finalize `
                   -id -id 428418101664119:1631181117066:180265
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

## Mode Parameters

If none are used, the script will be in list mode.

* -init: (optional) initialize a new migration
* -sync: (optional) perform manual sync now
* -finalize: (optional) finalize migration(s)
* -cancel: (optional) cancel migration(s)

## Filter Parameters for sync finalize or list modes

* -showAll: (optional) show completed tasks (only show in process migrations by default)
* -daysBack: (optional) days back to show for -showAll (default is 7)
* -name: (optional) only show/sync/finalize migration task with this name
* -filter: (optional) only show/sync/finalize migration tasks matching this string
* -id: (optional) only show/sync/finalize migration task matching this id
* -returnTaskIds: (optional) return resulting list of task IDs and exit
* -sourceServer: (optional) filter on -sourceServer and -sourceDB
* -sourceInstance: (optional) filter on -sourceInstance
* -sourceDB: (optional) one or more source DBs to filter on -sourceServer and -sourceDB (comma separated)
* -sourceDBList: (optional) text file of source DBs to filter on -sourceServer and -sourceDB (one per line)
* -targetServer: (optional) filter on -sourceServer and -sourceDB
* -targetDB: (optional) filter on -targetServer and -targetDB

## Init Mode Parameters

* -sourceServer: (required for init) Server name (or AAG name) where the database was backed up
* -sourceDB: (required for init) Original database name
* -sourceInstance: (optional) specify source instance name
* -targetServer: (required for init) Server name to migrate to
* -targetInstance: (optional) Instance name to restore to (defaults to MSSQLSERVER)
* -targetDB: (optional) New database name (defaults to same as sourceDB)
* -mdfFolder: (optional) Location to place the primary data file (e.g. C:\SQLData)
* -showPaths: (optional) show data/log file paths and exit
* -useSourcePaths: (optional) use same paths to restore to target server
* -ldfFolder: (optional) Location to place the log files (defaults to same as mdfFolder)
* -ndfFolders: (optional) Locations to place various ndf files (see below)
* -keepCdc: (optional) Keep change data capture during restore (default is false)
* -noRecovery: (optional) Restore the DB with NORECOVER option (default is to recover)
* -manualSync: (optional) Use manual sync mode (use auto sync by default)

## Multiple Folders for Secondary NDF Files

```powershell
-ndfFolders @{ '.*DataFile1.ndf' = 'E:\SQLData'; '.*DataFile2.ndf' = 'F:\SQLData'; }
```
