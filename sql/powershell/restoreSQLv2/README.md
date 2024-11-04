# Restore Multiple SQL Databases Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

`Note:` This script requires Cohesity 6.8.1 or later

This script restores one or more (or all) databases from the specified SQL server (not including the system databases).  

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreSQLv2'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreSQLv2.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/restoreSQLv2/restoreSQLv2.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To restore all databases (except system databases) to the original location:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -commit
```

To restore all databases (except system databases) to an alternate server:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -targetServer sqlserver2.mydomain.net `
                   -commit
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

## Source Parameters

* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceInstance: (optional) Name of source SQL instance to restore from
* -sourceNodes: (optional) Filter on databases from specific AAG nodes (comma separated)
* -sourceDB: (optional) One or more databases to restore (e.g. MyDB or MYINSTANCE/MyDB) (comma separated)
* -sourceDBList: (optional) Text file of databases to restore (e.g. MyDB or MYINSTANCE/MyDB) (one per line)
* -allDBs: (optional) restore all databases from specified server/instance
* -newerThan: (optional) when restoring allDBs, only include databases backed up in the last X days
* -includeSystemDBs: (optional) also restore system DBs (master, model, msdb)

## Target Parameters

* -targetServer: (optional) Server name to restore to (defaults to same as sourceServer)
* -targetInstance: (optional) SQL instance to restore to (defaults to MSSQLSERVER)

## Rename Parameters

* -targetDB: (optional) name of new database (only allowed when restoring one database)
* -prefix: (optional) Prefix to apply to database names (e.g. 'Dev')
* -suffix: (optional) Suffix to apply to database names (e.g. 'Dev')

## File Path Parameters

* -showPaths: (optional) show file paths for selected databases and exit without restore
* -exportPaths: (optional) export DB file path info and exit (file name is sourceserver.json)
* -importPaths: (optional) import DB file path info (use in conjunction with -useSourcePaths)
* -mdfFolder: (optional) Location to place the primary data file (e.g. C:\SQLData)
* -ldfFolder: (optional) Location to place the log files (defaults to same as mdfFolder)
* -ndfFolders: (optional) Locations to place various ndf files (see below)

## Point in Time Parameters

* -logTime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -logRangeDays: (optional) number of days to look back from specified log time (default is 14 days)
* -noStop: (optional) Replay the logs to the last transaction available

## Recovery Option Parameters

* -noRecovery: (optional) Restore the DB with NORECOVER option (default is to recover)
* -keepCdc: (optional) Keep CDC
* -captureTailLogs: (optional) Capture tail logs
* -overwrite: (optional) Overwrites an existing database (default is no overwrite)

## Misc Parameters

* -commit: (optional) perform the restores (otherwise just show what would be done)
* -wait: (optional) wait for the restore to complete and report end status (e.g. Succeeded)
* -progress: (optional) report percent complete per database during the restore
* -sleepTime: (optional) number of seconds to wait between status queries
* -pageSize: (optional) number of search results to collect at a time (default is 100)
* -dbsPerRecovery: (optional) number of databases to restore per restore task (default is 100)

## Deprecated Parameters

These parameters were in the previous version of the restore script but are now default behavior

* -latest: if -logTime is not specified, then the latest PIT is now automatically selected
* -useSourcePaths: if -mdfFolder is not specified, then the restore will try to use the original source paths
* -resume: if -overwrite is not specified, and the target DB exists and was left in NO RECOVERY mode, then a resume recovery will be performed

## Always On Availability Groups

Use the **AAG name** as the **-sourceServer** when restoring from an AAG backup (e.g. -sourceServer myAAG1)

## Overwrite Warning

Including the **-overwrite** parameter will overwrite an existing database. Use this parameter with extreme caution.

## Multiple Folders for Secondary NDF Files

```powershell
-ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
```

## Point in Time Recovery

By default, the last available log backup point in time is selected. For databases with no log backups, the last full/incremental backup is selected.

If you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

For databases with no log backups, the full/incremental backup that occured at or before -logTime will be selected.

If you want to ensure that you restore the very latest logs (to the millisecond) then use the **-noStop** parameter.
