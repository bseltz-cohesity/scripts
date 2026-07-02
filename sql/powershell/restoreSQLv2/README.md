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

## Example Command Lines

### Restoring all databases

To restore all databases (except system databases) to the original location, overwriting the existing databases:

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

To restore all databases, including the system databases (master, model, msdb):

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -includeSystemDBs `
                   -overWrite `
                   -commit
```

To restore only databases that were backed up within the last 7 days:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -newerThan 7 `
                   -overWrite `
                   -commit
```

### Restoring specific databases

To restore one or more named databases (comma separated) to their original location:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB1, MyDB2 `
                   -overWrite `
                   -commit
```

To restore a database from a non-default SQL instance, specify the instance along with the database name:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB SQLINSTANCE1/MyDB1 `
                   -overWrite `
                   -commit
```

To restore a list of databases from a text file (one database name per line):

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDBList ./dbList.txt `
                   -overWrite `
                   -commit
```

### Renaming databases during restore

To restore a single database under a new name (e.g. cloning to a test copy):

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -targetDB MyDB_Clone `
                   -commit
```

To restore multiple databases with a prefix applied to each name (e.g. creating Dev copies):

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -prefix Dev `
                   -commit
```

To restore multiple databases with a suffix applied to each name:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -suffix Test `
                   -commit
```

### Restoring to an alternate server or instance

To restore a single database to an alternate server under a new name:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -targetServer sqlserver2.mydomain.net `
                   -targetDB MyDB_Copy `
                   -commit
```

To restore to a different SQL instance on the same (or an alternate) server:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -targetServer sqlserver2.mydomain.net `
                   -targetInstance SQLINSTANCE2 `
                   -commit
```

### Controlling file placement

To restore specifying custom locations for the data and log files:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -targetDB MyDB_Copy `
                   -mdfFolder C:\SQLData `
                   -ldfFolder C:\SQLLogs `
                   -commit
```

To preview the file paths for the selected databases without performing a restore:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -showPaths
```

To export file path info for a server to a JSON file for later reuse:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -exportPaths
```

To restore using previously exported file path info instead of querying the source again:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -importPaths `
                   -overWrite `
                   -commit
```

To restore database files as flat (unattached) files to a folder, rather than attaching them as a live database:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -flatFilePath C:\restorefiles `
                   -commit
```

### Point-in-time restores

To restore to a specific point in time:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -logTime '2026-06-15 14:30:00' `
                   -overWrite `
                   -commit
```

To restore replaying the very latest available logs (to the millisecond):

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -noStop `
                   -overWrite `
                   -commit
```

To restore using only the full/incremental backup at or before a point in time, without replaying any logs:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -logTime '2026-06-15 14:30:00' `
                   -noLogs `
                   -overWrite `
                   -commit
```

To stage a database for further log restores by leaving it in NORECOVERY mode:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -sourceDB MyDB `
                   -targetServer sqlserver2.mydomain.net `
                   -noRecovery `
                   -commit
```

### Monitoring restore progress

To wait for the restore to finish and report the final status of each database:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -wait `
                   -commit
```

To display live percent-complete progress for each database as it restores:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -progress `
                   -commit
```

### Authentication variations

To connect using an API key instead of a username and password:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myApiKeyUser `
                   -useApiKey `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -commit
```

To connect through Helios/MCM to a specific managed cluster:

```powershell
./restoreSQLv2.ps1 -vip helios.cohesity.com `
                   -username myusername `
                   -domain mydomain.net `
                   -mcm `
                   -clusterName mycluster `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -commit
```

To connect using a TOTP multi-factor authentication code:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -mfaCode 123456 `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
                   -commit
```

To connect while impersonating a specific tenant/organization:

```powershell
./restoreSQLv2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -tenant myOrgName `
                   -sourceServer sqlserver1.mydomain.net `
                   -allDBs `
                   -overWrite `
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
* -flatFilePath: (optional) restore as flat files to this path (e.g. C:\restorefiles)

## Point in Time Parameters

* -logTime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -noLogs: (optional) use the incremental/full backup prior to the specified logTime (and replay no logs)
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

You can use the `-ndfFolders` parameter to specify a target folder for each secondary data file and log file like so:

```powershell
-ndfFolders @{'c:\sqldata2\multiDB.ndf' = 'e:\sqldata2'; 'c:\sqldata3\multiDB_1.ndf' = 'e:\sqldata3'; 'C:\sqllog2\multiDB_1.ldf'; 'e:\sqllogs2'}
```

You can also use regex matching syntax (`.*` means any number of any characters), like so:

```powershell
-ndfFolders @{'.*multiDB.ndf' = 'e:\sqldata2'; '.*multiDB_1.ndf' = 'e:\sqldata3'; '.*multiDB_1.ldf'= 'e:\sqllogs2'
```

## Point in Time Recovery

By default, the last available log backup point in time is selected. For databases with no log backups, the last full/incremental backup is selected.

If you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

For databases with no log backups, the full/incremental backup that occured at or before -logTime will be selected.

If you want to ensure that you restore the very latest logs (to the millisecond) then use the **-noStop** parameter.
