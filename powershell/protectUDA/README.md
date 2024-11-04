# Protect a Universal Data Adapter Source using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell creates a protection group for a Universal Data Adapter source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectUDA'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectUDA.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectUDA/protectUDA.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectUDA.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -jobName 'my uda job' `
                 -sourceName myuda1.mydomain.net `
                 -policyName mypolicy
```

## Basic Parameters

* -vip: (optional) Cohesity cluster or MCM to connect to (defaults to helios.cohesity.com)
* -username: (optional) Cohesity username (defaults to helios)
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -mcm: (optional) connect via MCM
* -clusterName: (optional) required when connecting through Helios or MCM
* -sourceName: name of the registered UDA source to protect
* -jobName: name of protection job to create
* -policyName: name of protection policy to use
* -objectName: (optional) one or more database names to protect (comma separated)

## UDA Parameters

* -concurrency: (optional) number of concurrent backup streams (default is 1)
* -mounts: (optional) number of mounts (default is 1)
* -fullBackupArgs: (optional) default is ""
* -incrBackupArgs: (optional) default is ""
* -logBackupArgs: (optional) default is ""

## Optional Job Parameters

* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
