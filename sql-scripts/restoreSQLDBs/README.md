# Restore Multiple SQL Databases Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores one or more (or all) databases from the specified SQL server (not including the system databases).  

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreSQLDBs'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -Uri "$repoUrl/sql-scripts/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* restoreSQLDBs.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreSQLDBs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -sourceServer sqlserver1.mydomain.net `
                    -allDBs `
                    -overWrite `
                    -latest
```

## Parameters

### Basic Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -sourceServer: Server name (or AAG name) where the database was backed up

### Source DB Selections

* -sourceDBnames: (optional) Databases to restore (e.g. MyDB or MYINSTANCE/MyDB) comma separated list
* -sourceDBList: (optional) Text file containing databases to restore (e.g. MyDB or MYINSTANCE/MyDB)
* -sourceInstance: (optional) Name of source SQL instance to restore from
* -allDBs: (optional) restore all databases from specified server/instance

### Point in Time Selections

* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: Replay the logs to the latest point in time available

### Target Parameters

* -prefix: (optional) Prefix to apply to database names (e.g. 'Dev-')
* -suffix: (optional) Suffix to apply to database names (e.g. '-Dev')
* -targetServer: (optional) Server name to restore to (defaults to same as sourceServer)
* -targetInstance: (optional) SQL instance to restore to (defaults to MSSQLSERVER)
* -mdfFolder: (optional) Location to place the primary data file (e.g. C:\SQLData)
* -ldfFolder: Location to place the log files (defaults to same as mdfFolder)
* -ndfFolders: Locations to place various ndf files (see below)
* -overwrite: Overwrites an existing database (default is no overwrite)
* -noRecovery: Restore the DB with NORECOVER option (default is to recover)

### Misc Parameters

* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)
* -progress: (optional) display percent complete

## Always On Availability Groups

Use the **AAG name** as the **-sourceServer** when restoring from an AAG backup (e.g. -sourceServer myAAG1)

## Overwrite Warning

Including the **-overwrite** parameter will overwrite an existing database. Use this parameter with extreme caution.

## Multiple Folders for Secondary NDF Files

```powershell
-ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
```

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

Note that when the -logTime parameter is used with databases where no log backups exist, the full/incremental backup that occured at or before the specified log time will be used.
