# Update Oracle DB Credentials using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script sets the database username and password for an Oracle protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateOracleDbCredentials'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/oracle/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateOracleDbCredentials.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/powershell/updateOracleDbCredentials/updateOracleDbCredentials.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./updateOracleDbCredentials.ps1 -vip mycluster -username myusername -domain mydomain.net -oracleServer oracle1.mydomain.net -oracleUser backup -oraclePwd oracle
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: your AD domain (defaults to local)
* -oracleServer: name of registered oracle source to be updated
* -oracleUserName: name of Oracle DB user
* -oraclePwd: password for Oracle DB user
