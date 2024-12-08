# Restore an Oracle Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs an restore of an Oracle database. The script can restore the database to the original server, or a different server.

Note: this is a major rewrite of the previous restoreOracle.ps1 script and may need significant testing to shake out any flaws. Please provide feedback if you try it out and find any issues.

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreOracle-v2'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreOracle-v2.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/restoreOracle-v2/restoreOracle-v2.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Restoring a DB to the original location:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer oracle.mydomain.net -sourceDB cohesity `
                       -latest
```

Restoring a DB to an alternate location:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer oracle.mydomain.net -sourceDB cohesity `
                       -targetServer oracle2.mydomain.net -targetDB testdb `
                       -oracleHome /opt/oracle/product/19c/dbhome_1 `
                       -oracleBase /opt/oracle `
                       -oracleData /opt/oracle/oradata/testdb
```

Restoring a PDB to the original location. Note: when restoring a PDB name, the source DB should be in the form of CDBNAME/PDBName:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer oracle.mydomain.net -sourceDB cdb1/pdb1 `
                       -latest -overwrite
```

Restoring a PDB to an alternate location. Note: when restoring a PDB name, the source DB should be in the form of CDBNAME/PDBName:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer oracle.mydomain.net -sourceDB cdb1/pdb1 `
                       -targetServer oracle2.mydomain.net -targetDB pdb2 `
                       -oracleHome /opt/oracle/product/19c/dbhome_1 `
                       -oracleBase /opt/oracle `
                       -oracleData /opt/oracle/oradata/pdb2 `
                       -progress -latest -targetCDB cdb2
```

Restore a CDB with two PDBs to an alternate location:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer oracle.mydomain.net -sourceDB cdb1 `
                       -targetServer oracle2.mydomain.net -targetDB cdb2 `
                       -oracleHome /opt/oracle/product/19c/dbhome_1 `
                       -oracleBase /opt/oracle `
                       -oracleData /opt/oracle/oradata/cdb2 `
                       -pdbNames pdb1, pdb2 -latest
```

Restoring an Oracle RAC DB:

```powershell
./restoreOracle-v2.ps1 -vip mycluster -username myusername -domain mydomain.net `
                       -sourceServer orascan1 -sourceDB RacDB `
                       -targetServer orascan2 -targetDB RacDB2 `
                       -oracleHome /opt/oracle/product/19c/dbhome_1 `
                       -oracleBase /opt/oracle `
                       -oracleData /opt/oracle/oradata/RacDB2 `
                       -channelNode orarac1.mydomain.net `
                       -channels 4
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
* -sourceDB: Original database name
* -overwrite: (optional) Overwrites an existing database (default is no overwrite)
* -channels: (optional) Number of restore channels
* -channelNode: (optional) RAC node to use for channels
* -wait: (optional) wait for restore to finish and report result
* -progress: (optional) display percent complete
* -instant: (optional) perform instant recovery

## Container/Pluggable DB Parameters

* -pdbNames: (optional) PDBs to restore when restoring a CDB (default is all PDBs)
* -targetCDB: (optional) CDB to restore to when restoring a PDB

## Point in Time Parameters

* -logTime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: (optional) Replay the logs to the latest point in time available
* -noRecovery: (optional) Restore the DB with NORECOVER option (default is to recover)

## Alternate Destination Parameters

* -targetServer: (optional) Server name to restore to (defaults to same as sourceServer)
* -targetDB: (optional) New database name (defaults to same as sourceDB)
* -oracleHome: oracle home path (not required when overwriting original db)
* -oracleBase: oracle base path (not required when overwriting original db)
* -oracleData: oracle data path (not required when overwriting original db)

## Advanced Parameters

* -noFilenameCheck: (optional) skip filename conflict check (use caution)
* -noArchiveLogMode: (optional) do not enable archive log mode on restored DB
* -numTempFiles: (optional) number of temp files
* -newNameClause: (optional) new name clause
* -numRedoLogs: (optional) number of redo log groups
* -redoLogSizeMB: (optional) size of redo log groups (default is 20)
* -redoLogPrefix: (optional) redo log prefix
* -bctFilePath: (optional) alternate bct file path
* -pfileParameterName: (optional) one or more parameter names to include in pfile (comma separated)
* -pfileParameterValue: (optional) one or more parameter values to include in pfile (comma separated)
* -pfileList: (optional) text file of pfile parameters (one per line)
* -clearPfileParameters: (optional) delete existing pfile parameters
* -shellVarName: (optional) one or more shell variable names (comma separated)
* -shellVarValue: (optional) one or more shell variable values (comma separated)
* -dbg: (optional) display api payload and exit (without restoring)

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter.

Or, if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

## PFile Parameters

By default, Cohesity will generate a list of pfile parameters from the source database, with basic adjustments for the target database. You can override this behavior in a few ways.

* You can add or override individual pfile parameters using -pfileParameterName and -pfileParameterValue, e.g. `-pfileParameterName DB_RECOVERY_FILE_DEST_SIZE -pfileParameterValue "32G"`
* You can provide a text file containing multiple pfile parameters using -pfileList, e.g. `-pfileList ./my_pfile.txt`
* You can clear all existing pfile parameters and provide a complete pfile using -clearPfileParameters and -pfileList, e.g. `-clearPfileParameters -pfileList ./my_pfile.txt`
