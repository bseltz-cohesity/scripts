# Get Latest Recovery Point for a SQL Database Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script shows the protection status for an object.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'latestSQLRecoveryPoint'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [latestSQLRecoveryPoint.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/latestSQLRecoveryPoint/latestSQLRecoveryPoint.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./latestRecoveryPoint.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -serverName myserver.mydomain.net `
                          -dbName mydatabase
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -serverName: name of SQL server
* -dbName: name of database

## Return Values

The script will return a dictionary containing properties like so:

```json
{
  "jobName": "VE3 SQL VDI",
  "jobId": 56267,
  "backupType": "kSqlNative",
  "backupDate": "2020-09-10T09:39:18.34-04:00",
  "backupDateUsecs": 1599745158340421,
  "jobRunId": 76909
}
```

So for programmatic purposes, you can return the script output to a variable and reference the properties, like so:

```powershell
$result = ./latestRecoveryPoint.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -serverName myserver.mydomain.net `
                          -dbName mydatabase

$result.backupType
kSqlNative

$result.backupDate
Thursday, September 10, 2020 9:39:18 AM

$result.backupDate.DayOfWeek
Thursday

$result.jobName
VE3 SQL VDI
```
