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
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/restoreSQL/restoreSQL.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# examples

# restore to the original location
./restoreSQL.ps1 -vip mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -sourceServer mysqlserver `
                 -sourceDB mydb `
                 -overwrite `
                 -latest

# restore to an alternate location
./restoreSQL.ps1 -vip mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -sourceServer mysqlserver `
                 -sourceDB mydb `
                 -targetServer sqlserver2 `
                 -targetDB restoredb `
                 -mdfFolder c:\sqldata `
                 -ldfFolder c:\sqllogs `
                 -latest
# end examples

# restore to an alternate location using Helios (enter Helios API Key when prompted for password)
./restoreSQL.ps1 -clusterName mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -sourceServer mysqlserver `
                 -sourceDB mydb `
                 -targetServer sqlserver2 `
                 -targetDB restoredb `
                 -mdfFolder c:\sqldata `
                 -ldfFolder c:\sqllogs `
                 -latest
# end examples
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

## Basic Parameters

* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceDB: Original database name e.g. MYDB or MYINSTANCE/MYDB
* -overwrite: Overwrites an existing database (default is no overwrite)
* -sourceInstance: one or more instance names (see below)
* -sourceNodes: (optional) Limit source results to these AAG nodes (comma separated)

## Alternate Target Parameters

* -mdfFolder: Location to place the primary data file (e.g. C:\SQLData)
* -targetServer: Server name to restore to (defaults to same as sourceServer)
* -targetDB: New database name (defaults to same as sourceDB)
* -targetInstance: Instance name to restore to (defaults to MSSQLSERVER)
* -showPaths: show data/log file paths and exit
* -useSourcePaths: use same paths to restore to target server
* -ldfFolder: Location to place the log files (defaults to same as mdfFolder)
* -ndfFolder: Location to place the secondary files (defaults to same as ndfFolder)
* -ndfFolders: Locations to place various ndf files (see below)

## Point in Time Parameters

* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: Replay the logs to the latest log backup date
* -noStop: Replay the logs to the last transaction available
* -captureTailLogs: Replay logs that haven't been backed up yet (only applies when overwriting original database)

## Restore Options

* -keepCdc: Keep change data capture during restore (default is false)
* -withClause: VDI with clause e.g. `-withClause "WITH BUFFERCOUNT = 256,MAXTRANSFERSIZE = 4194304"`
* -noRecovery: Restore the DB with NORECOVER option (default is to recover)
* -resume: Resume recovery of previously restored database (left in NORECOVERY mode)
* -update: short hand for -resume -noRecovery -latest
* -restoreFromArchive: force restore from archive even if local snapshot exists

## Other Parameters

* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)
* -progress: display percent complete
* -sleepTimeSecs: sleep between status queries (default is 30 seconds)
* -returnErrorMessage: return error message to calling PowerShell session

## Always On Availability Groups

Use the **AAG name** as the **-sourceServer** when restoring from an AAG backup, like `-sourceServer myAAG1`

## Source Intances

By default, the script will default to MSSQLSERVER as the source instance. You can specify a source instance in a few ways:

* You can specify the source instance as part of the -sourceDB parameter, like `-sourceDB MYINSTANCE/MYDB`
* You can specify the source instance using the -sourceInstance parameter, like `-sourceInstance MYINSTANCE`
* For AAG, if the AAG nodes have different instance names, you can specify multiple instance names like `-sourceInstance AAGINSTANCE1, AAGINSTANCE2`

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
