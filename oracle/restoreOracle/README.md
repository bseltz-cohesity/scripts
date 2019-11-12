# Restore an Oracle Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an restore of an Oracle database. The script can restore the database to the original server, or a different server. It can overwrite the existing database or restore with a different database name.  

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreOracle'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* restoreOracle.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreOracle.ps1 -vip mycluster -username myusername -domain mydomain.net `
                    -sourceServer oracle.mydomain.net -sourceDB cohesity `
                    -targetServer oracle2.mydomain.net -targetDB testdb `
                    -oracleHome /home/oracle/app/oracle/product/11.2.0/dbhome_1 `
                    -oracleBase /home/oracle/app/oracle `
                    -oracleData /home/oracle/app/oracle/oradata/testdb

```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceDB: Original database name
* -targetServer: Server name to restore to (defaults to same as sourceServer)
* -targetDB: New database name (defaults to same as sourceDB)
* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: Replay the logs to the latest point in time available
* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)
* -overwrite: Overwrites an existing database (default is no overwrite)
* -noRecovery: Restore the DB with NORECOVER option (default is to recover)
* -progress: (optional) display percent complete

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```
