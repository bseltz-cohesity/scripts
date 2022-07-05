# Destroy Clone Using PowerShell Example

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to tear down a cloned SQLDB, VM, or View.  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'destroyClone'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* destroyClone.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./destroyClone.ps1 -vip mycluster -username admin -cloneType sql -dbName cohesitydb-test -dbServer sqldev01

Connected!
tearing down SQLDB: cohesitydb-test from sqldev01...
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -cloneType: type of clone to destroy ('sql', 'view', 'vm', 'oracle')
* -viewName: name of clone view to tear down
* -vmName: name of clone VM to tear down
* -dbName: name of clone DB to tear down
* -dbServer: name of dbServer where clone is attached
* -instance: name of SQL instance where clone is attached (default is MSSQLSERVER)
* -wait: wait for completion before exit
