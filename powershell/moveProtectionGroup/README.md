# Move Protection Group to new Storage Domain Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script migrates a protection group from one storage domain to another.

**Note:** that existing snapshots can not be migrated. They can either be left to expire as scheduled or deleted (manually, later, in the UI). If left to expire, please note that the new job will consume additional storage in the new storage domain, thus increasing the overall cluster storage consumption until the old snapshots expire.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'moveProtectionGroup'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* moveProtectionGroup.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./moveProtectionGroup.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName 'My Job' `
                          -newStorageDomainName otherStorageDomain
```

## Parameters

* -vip: DNS or IP of the Cohesity Cluster
* -username: Cohesity User Name
* -domain: (optional) defaults to 'local'
* -jobName: (optional) one or more protection group names to migrate (comma separated)
* -jobList: (optional) text file of protection group names to migrate (one per line)
* -newStorageDomainName: name of storage domain to migrate to
* -prefix: (optional) add a prefix to the name of the new protection group
* -suffix: (optional) add a suffix to the name of the new protection group
* -deleteOldJob: (optional) delete the old protection group
* -newPolicyName: (optional) change the policy used by the job
* -pauseOldJob: (optional) pause the old job
* -pauseNewJob: (optional) pause the new job

## Notes

You must use either -prefix, -suffix or -deleteOldJob to avoid conflicting job names.

In some cases it's not possible to protect the same object in two jobs (e.g. SQL servers), so it's nessesary to use -deleteOldJob in those cases.
