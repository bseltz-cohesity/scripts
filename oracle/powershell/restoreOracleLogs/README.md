# Restore Oracle Archive Logs Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs a restore of Oracle archive logs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreOracleLogs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreOracleLogs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/restoreOracleLogs/restoreOracleLogs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreOracleLogs.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -sourceServer oracleprod.mydomain.net `
                        -sourceDatabase proddb `
                        -path /home/oracle/test
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

* -path: path to restore archive logs (e.g. /home/oracle/test)
* -sourceServer: Server name (or AAG name) where the database was backed up
* -sourceDB: Original database name
* -channels: (optional) Number of restore channels
* -channelNode: (optional) RAC node to use for channels
* -wait: (optional) wait for restore to finish and report result
* -progress: (optional) display percent complete
* -dbg: (optional) output JSON payload for debugging

## Log Range Parameters

* -rangeType: (optional) lsn, scn, or time (default is lsn)
* -showRanges: (optional) show available ranges (of selected range type) and exit
* -startTime: (optional) use when using time range type (e.g. '2024-12-01 21:00:00')
* -endTime: (optional) use when using time range type (e.g. '2024-12-01 23:00:00')
* -startOfRange: (optional) use when using lsn or scn range types (e.g. 1257)
* -endOfRange: (optional) use when using lsn or scn range types (e.g. 1259)
* -incarnationId: (optional) specify incarnation ID
* -resetLogId: (optional) specify reset log ID
* -threadId: (optional) specify thread ID

## Alternate Destination Parameters

* -targetServer: (optional) Server name to restore to (defaults to same as sourceServer)
* -targetDB: (optional) New database name (defaults to same as sourceDB)
* -oracleHome: oracle home path (not required when overwriting original db)
* -oracleBase: oracle base path (not required when overwriting original db)
