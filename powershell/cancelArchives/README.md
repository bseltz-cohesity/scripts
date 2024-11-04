# Cancel Archive Tasks Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists the currently active archive tasks and outputs to a CSV.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cancelArchives'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cancelArchives.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cancelArchives/cancelArchives.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cancelArchives.ps1 -vip mycluster -username myusername -domain mydomain.net -cancelAll
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
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) focus on just one job
* -cancelAll: (optional) cancel all archive tasks
* -cancelQueued: (optional) cancel archive tasks that haven't moved any data yet
* -cancelOutdated: (optional) cancel archives that would be expired by now
* -cancelOlderThan: (optional) cancel archives that for runs that started X days ago or more
* -commit: (optional) perform the cancellations (test run if omitted)
* -showFinished: (optional) display historical finished archive tasks
* -numRuns: (optional) number of runs to get per API call (default is 1000)
* -unit: (optional) units for display (MiB, GiB, TiB) default is MiB
* -targetName: (optional) limit actions to specific archive target
* -logsOnly: (optional) limit actions to log runs only
