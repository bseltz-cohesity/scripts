# Protect Oracle using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects Oracle Databases.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectOracle'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* protectOracle.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script.

To add a single database to an existing protection job:

```powershell
./protectOracle.ps1 -vip mycluster -username admin -jobname 'Oracle Backup' -servervmname oracle1.mydomain.net -dbname myDB
```

or to add all databases from a server:

```powershell
./protectOracle.ps1 -vip mycluster -username admin -jobname 'Oracle Backup' -servervmname oracle1.mydomain.net
```

or to create a new protection job:

```powershell
./protectOracle.ps1 -vip mycluster -username admin -jobname 'New Oracle Backup' -policyname 'My Policy' -servervmname oracle1.mydomain.net
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -jobname: name of protection job (new or existing)
* -servername: name of Oracle server to protect
* -dbname: (optional) name of database to protect (defaults to all dbs)
* -policyname: (optional) name of policy to apply to new job
* -storagedomain: (optional) name of storage domain for new job (defaults to DefaultStorageDomain)
* -timezone: (optional) timezone for job (defaults to America/New_York)
* -starttime: (optional) start time for job (defaults to 20:00)
