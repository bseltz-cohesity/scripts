# Cancel Archive Tasks Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists the currently active archive tasks and outputs to a CSV.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cancelArchivesV2'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* cancelArchivesV2.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cancelArchivesV2.ps1 -vip mycluster -username myusername -domain mydomain.net -cancelAll
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -jobName: (optional) focus on just one job
* -cancelAll: (optional) cancel all archive tasks
* -cancelQueued: (optional) cancel archive tasks that haven't moved any data yet
* -cancelOutdated: (optional) cancel archives that would be expired by now
* -cancelOlderThan: (optional) cancel archives that for runs that started X days ago or more
* -commit: (optional) perform the cancellations (test run if omitted)
* -showFinished: (optional) display historical finished archive tasks
* -numRuns: (optional) number of runs to get per API call (default is 1000)
* -unit: (optional) units for display (MiB, GiB, TiB) default is MiB
