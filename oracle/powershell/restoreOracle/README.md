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
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreOracle.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/restoreOracle/restoreOracle.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreOracle.ps1 -vip mycluster -username myusername -domain mydomain.net `
                    -sourceServer oracle.mydomain.net -sourceDB cohesity `
                    -targetServer oracle2.mydomain.net -targetDB testdb `
                    -oracleHome /home/oracle/app/oracle/product/11.2.0/dbhome_1 `
                    -oracleBase /home/oracle/app/oracle `
                    -oracleData /home/oracle/app/oracle/oradata/testdb

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

## Basic Parameters

* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceDB: Original database name
* -overwrite: Overwrites an existing database (default is no overwrite)
* -channels: Number of restore channels
* -channelNode: RAC node to use for channels

## Point in Time Parameters

* -logTime: Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: Replay the logs to the latest point in time available
* -noRecovery: Restore the DB with NORECOVER option (default is to recover)

## Alternate Destination Parameters

* -targetServer: Server name to restore to (defaults to same as sourceServer)
* -targetDB: New database name (defaults to same as sourceDB)
* -oracleHome: oracle home path (not required when overwriting original db)
* -oracleBase: oracle base path (not required when overwriting original db)
* -oracleData: oracle data path (not required when overwriting original db)
* -controlfile: (optional) alternate control file path
* -redologpath: (optional) alternate redo log path
* -auditpath: (optional) alternate audit path
* -diagpath: (optional) alternate diag path
* -frapath: (optional) alternate fra path
* -frasizeMB: (optional) alternate fra size in MB
* -bctfile: (optional) alternate bct file path
* -pfileParameterName: (optional) one or more parameter names to include in pfile (comma seaparated)
* -pfileParameterValue: (optional) one or more parameter values to include in pfile (comma separated)
* -pfileList: (optional) text file of pfile parameters (one per line)
* -clearPfileParameters: (optional) delete existing pfile parameters

## Miscellaneous Parameters

* -wait: Wait for the restore to complete and report end status (e.g. kSuccess)
* -progress: (optional) display percent complete

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

## PFile Parameters

Note: the number and order of pfileParameterNames must match the number and order of pfileParameterValues.

By default, Cohesity will generate a list of pfile parameters from the source database, with basic adjustments for the target database. You can override this behavior in a few ways.

* You can add or override individual pfile parameters using -pfileParameterName and -pfileParameterValue, e.g. `-pfileParameterName DB_RECOVERY_FILE_DEST_SIZE -pfileParameterValue "32G"`
* You can provide a text file containing multiple pfile parameters using -pfileList, e.g. `-pfileList ./my_pfile.txt`
* You can clear all existing pfile parameters and provide a complete pfile using -clearPfileParameters and -pfileList, e.g. `-clearPfileParameters -pfileList ./my_pfile.txt`
