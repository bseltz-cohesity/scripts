# Restore a SQL Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an restore of a SQL database. The script can restore the database to the original server, or a different server. It can overwrite the existing database or restore with a different database name.  

## Warning!!

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Components

* restore-SQL.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restore-SQL.ps1 -vip mycluster -username admin -sourceServer sql2012 -sourceDB cohesitydb -targetServer sqldev01 -targetDB restoreTest -mdfFolder c:\sqldata -ndfFolder c:\sqldata\ndf -ldfFolder c:\sqldata\logs

Connected!
Restoring cohesitydb to sqldev01 as restoreTest
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -sourceServer: Server name where the database was backed up
* -sourceDB: Original database name
* -targetServer: Server name to restore to (defaults to same as sourceServer)
* -targetDB: New database name (defaults to same as sourceDB)
* -targetInstance: Instance name to restore to (defaults to MSSQLSERVER)
* -overwrite: Overwrites an existing database (default is no overwrite)
* -mdfFolder: Location to place the primary data file (e.g. C:\SQLData)
* -ldfFolder: Location to place the log files (defaults to same as mdfFolder)
* -ndfFolder: Location to place the secondary files (defaults to same as ndfFolder)
* -ndfFolders: Locations to place various ndf files (see below)
* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)

Note: if you want to restore multiple ndf files to separate locations, use the following parameter:

```powershell
-ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
```

If you want to replay logs to a point in time, use this parameter:

```powershell
-logTime '2019-01-20 23:47:02'
```

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreSQL/restore-SQL.ps1).content | Out-File restore-SQL.ps1; (Get-Content restore-SQL.ps1) | Set-Content restore-SQL.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreSQL/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```
