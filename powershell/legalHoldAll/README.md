# Add or Remove Legal Hold from All Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script add or remove legal hold from all existing backups.

Runs or objects placed on legal hold will not expire when their retention end date is reached. Instead, they will be retained until the legal hold is removed. Note that the user adding or removing legal hold must have the `Data Security` role assigned to their account.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'legalHoldAll'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [legalHoldAll.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/legalHoldAll/legalHoldAll.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

To list the current hold state of all backups:

```powershell
./legalHoldAll.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net
```

To list the current hold state of all backups for protection groups with names containing the string 'VMs':

```powershell
./legalHoldAll.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -jobMatch 'vms'
```

To add legal hold to all backups:

```powershell
./legalHoldAll.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -addHold
```

Or remove legal hold from all backups:

```powershell
./legalHoldAll.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -removeHold
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) one or more job names (comma separated) to apply hold (all jobs by default)
* -jobList: (optional) text file of job names to apply hold (one per line)
* -jobMatch: (optional) narrow scope to just jobs that match any of these strings (comma separated)
* -addHold: (optional) add legal hold to all backups for selected jobs (all jobs by default)
* -removeHold: (optional) remove legal host from all backups for selected jobs (all jobs by default)
* -showTrue: (optional) display backups where legal hold is True
* -showFalse: (optional) display backups where legal hold is False
* -pushToReplica: (optional) push legal hold adds/removes to replicas
