# Protect VMware VMs by Tag using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds include/exclude VM tags to a new or existing protection group.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectVMsByTag'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectVMsByTag.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectVMsByTag/protectVMsByTag.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

To create a new protection job:

```powershell
# example
./protectVMsByTag.ps1 -vip mycluster `
                      -userName myuser `
                      -domain mydomain.net `
                      -vCenterName myvcenter.mydomain.net `
                      -jobName 'my vm job' `
                      -policyName mypolicy `
                      -includeTag 'my tag 1'
# end example
```

For a compound tag (where a VM must have both tags to be included):

```powershell
# example
./protectVMsByTag.ps1 -vip mycluster `
                      -userName myuser `
                      -domain mydomain.net `
                      -vCenterName myvcenter.mydomain.net `
                      -jobName 'my vm job' `
                      -policyName mypolicy `
                      -includeTag 'my tag 1', 'my tag 2'
# end example
```

## Mandatory Parameters

* -vip: name or IP of Cohesity cluster
* -userName: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobName: name of protection job to create or add to
* -vCenterName: name of registered vCenter source

## Optional Prameters

* -includeTag: (optional) VM tag to include
* -excludeTag: (optional) VM tag to exclude
* -tenant: (optional) impersonate a Cohesity tenant

## Optional Parameters for New Jobs Only

* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)
* -appConsistent: (optional) quiesce VMs during backup
* -noStorageeDomain: (optional) do not specify storage domain (for CAD and NGCE deployments)
