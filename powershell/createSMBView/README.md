# Create an SMB View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers a list of generic NAS shares as sources on Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/createSMBView/createSMBView.ps1).content | Out-File createSMBView.ps1; (Get-Content createSMBView.ps1) | Set-Content createSMBView.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/createSMBView/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* createSMBView.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./createSMBView.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -viewName newview1 `
                    -readWrite mydomain.net\server1 `
                    -fullControl mydomain.net\admingroup1, mydomain.net\admingroup2 `
                    -qosPolicy 'TestAndDev High' `
                    -storageDomain mystoragedomain
#end example
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: name of new view to create
* -readWrite: comma separated list of principals to grant read/write access
* -fullControl: comma separated list of principals to grant full control
* -qosPolicy: defaults to 'Backup Target Low' or choose 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low'
* -storageDomain: name of storage domain to place view data. Defaults to DefaultStorageDomain
