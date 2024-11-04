# Create or Edit Cohesity Protection Policy Blackout Windows Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script creates repeating blackout windows every X minutes starting at midnight, for a new or existing protection policy.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'intervalPolicy'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/intervalPolicy.ps1").content | Out-File "intervalPolicy.ps1"; (Get-Content "intervalPolicy.ps1") | Set-Content "intervalPolicy.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [intervalPolicy.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/intervalPolicy/intervalPolicy.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Example

Place the files in a folder together and run the script like so:

```powershell
./intervalPolicy.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -policyName 'my policy' `
                     -intervalMinutes 20
```

The policy will now have a fequency of 20 minutes and blackout windows such that the jobs will run at 12:00, 12;20, 12:40, etc.

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -policyName: name of policy to create
* -intervalMinutes: minutes between backups
* -offset: offset intervals by X minutes (e.g. 20 - start backups at 20 after the hour)
* -daysToKeep: retention period
* -retries: (optional) default is 3
* -retryInterval (optional) default is 30 (minutes)
