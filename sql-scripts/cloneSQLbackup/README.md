# Clone SQL Backup Files to a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones SQL backup files to a Cohesity view.

## Warning! This script can delete views! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'cloneSQLbackup'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* cloneSQLbackup.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

To clone all available backups:

```powershell
./cloneSQLbackup.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -jobName 'My SQL Job' `
                     -sqlServer mysqlserver.mydomain.net `
                     -viewName cloned
```

To limit access to specific users:

```powershell
./cloneSQLbackup.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -jobName 'My SQL Job' `
                     -sqlServer mysqlserver.mydomain.net `
                     -viewName cloned `
                     -access 'mydomain.net\domain admins', mydomain.net\othergroup
```

To list available runs:

```powershell
./cloneSQLbackup.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -jobName 'My SQL Job' `
                     -listRuns
```

To clone a specific range of run dates:

```powershell
./cloneSQLbackup.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -jobName 'My SQL Job' `
                     -sqlServer mysqlserver.mydomain.net `
                     -viewName cloned `
                     -firstRunId 12345 `
                     -lastRunId 12399
```

To delete a view when finished:

```powershell
./cloneSQLbackup.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -viewName cloned `
                     -deleteView
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -jobname: (optional) name of SQL protection job
* -firstRunId: (optional) earliest run to clone (defaults to all)
* -lastRunId: (optional) most recent run to clone (defaultds to all)
* -sqlServer: (optional) name of sqlServer whose backup to clone
* -viewName: (optional) name of new or existing view to clone backup files to
* -access: (optional) Active Directory users/groups (comma separated) to add to share permissions (default is everyone)
* -storageDomain: (optional) name of storage domain to create view (defaults to DefaultStorageDomain)
* -listRuns: (optional) list available job run IDs and dates
* -deleteView: (optional) delete view when finished
