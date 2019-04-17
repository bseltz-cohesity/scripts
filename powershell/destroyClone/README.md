# Destroy Clone Using PowerShell Example

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to tear down a cloned SQLDB, VM, or View.  

## Components

* destroyClone.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./destroyClone.ps1 -vip mycluster -username admin -cloneType sql -dbName cohesitydb-test -dbServer sqldev01

Connected!
tearing down SQLDB: cohesitydb-test from sqldev01...
```

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/destroyClone/destroyClone.ps1).content | Out-File destroyClone.ps1; (Get-Content destroyClone.ps1) | Set-Content destroyClone.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/destroyClone/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```
