# Migrate Protection Job to new Storage Domain Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script migrates a protection job from one storage domain to another.

**Note:** that existing snapshots can not be migrated. They can either be left to expire as scheduled or deleted. If left to expire, please note that the new job will consume additional storage in the new storage domain, thus increasing the overall cluster storage consumption until the old snapshots expire.

**Warning:** Using the parameter `-deleteOldSnapshots` will delete existing backups! Make sure you know what you're doing before using this parameter.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateProtectionJob'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* migrateProtectionJob.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./migrateProtectionJob.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -jobName 'My Job' `
                           -prefix 'New-' `
                           -newStorageDomain otherStorageDomain `
                           -pauseOldJob
```

## Parameters

* -vip: DNS or IP of the Cohesity Cluster
* -username: Cohesity User Name
* -domain: - defaults to 'local'
* -jobName: one or more jobs to migrate (comma separated)
* -jobList: text file of jobs to migrate (one per line)
* -newStorageDomain: name of storage domain to migrate to
* -prefix: prefix to apply to new protection job name
* -suffix: suffix to apply to new protection job name
* -pauseOldJob: pause old protection job
* -pauseNewJob: pause new protection job
* -deleteOldJob: delete old protection job
* -deleteOldSnapshots: delete old protection job and delete existing snapshots
