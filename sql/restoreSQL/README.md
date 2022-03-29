# Restore a SQL Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an restore of a SQL database. The script can restore the database to the original server, or a different server. It can overwrite the existing database or restore with a different database name.  

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreSQL'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -Uri "$repoUrl/sql/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* restoreSQL.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreSQL.ps1 -vip mycluster -username admin -sourceServer sql2012 -sourceDB cohesitydb -targetServer sqldev01 -targetDB restoreTest -mdfFolder c:\sqldata -ndfFolder c:\sqldata\ndf -ldfFolder c:\sqldata\logs

Connected!
Restoring cohesitydb to sqldev01 as restoreTest
```

## Parameters

### Basic Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceDB: Original database name
* -mdfFolder: Location to place the primary data file (e.g. C:\SQLData)

To specify a source instance, include the instance name in the sourceDB name, like MYINSTANCE/MyDB

### Optional Parameters

* -clusterName: Specify cluster name when connected through Helios
* -targetServer: Server name to restore to (defaults to same as sourceServer)
* -targetDB: New database name (defaults to same as sourceDB)
* -targetInstance: Instance name to restore to (defaults to MSSQLSERVER)
* -showPaths: show data/log file paths and exit
* -useSourcePaths: use same paths to restore to target server
* -ldfFolder: Location to place the log files (defaults to same as mdfFolder)
* -ndfFolder: Location to place the secondary files (defaults to same as ndfFolder)
* -ndfFolders: Locations to place various ndf files (see below)
* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: Replay the logs to the latest log backup date
* -noStop: Replay the logs to the last transaction available
* -captureTailLogs: Replay logs that haven't been backed up yet (only applies when overwriting original database)
* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)
* -overwrite: Overwrites an existing database (default is no overwrite)
* -keepCdc: Keep change data capture during restore (default is false)
* -noRecovery: Restore the DB with NORECOVER option (default is to recover)
* -resume: Resume recovery of previously restored database (left in NORECOVERY mode)
* -progress: display percent complete
* -helios: use on-prem helios
* -update: short hand for -resume -noRecovery -latest

## Always On Availability Groups

Use the **AAG name** as the **-sourceServer** when restoring from an AAG backup (e.g. -sourceServer myAAG1)

## Overwrite Warning

Including the **-overwrite** parameter will overwrite an existing database. Use this parameter with extreme caution.

## Multiple Folders for Secondary NDF Files

```powershell
-ndfFolders @{ '.*DataFile1.ndf' = 'E:\SQLData'; '.*DataFile2.ndf' = 'F:\SQLData'; }
```

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

Note that when the -logTime parameter is used with databases where no log backups exist, the full/incremental backup that occured at or before the specified log time will be used.
