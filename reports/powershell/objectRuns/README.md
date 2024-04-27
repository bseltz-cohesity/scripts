# Generate a Protection Group Inventory and Schedule Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script generates a report of per object protection stats over the past X days, and outputs to CSV format.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'objectRuns'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [objectRuns.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/objectRuns/objectRuns.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./objectRuns.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) password or API key (will use stored password by default)
* -jobName: (optional) names of jobs to focus on (comma separated)
* -jobList: (optional) text file of names of jobs to focus on (one per line)
* -numRuns: (optional) number of runs to retrieve at a time (default is 100)
* -daysBack: (optional) number of days of stats to retrieve (default is 7)
* -unit: (optional) display stats in 'KiB','MiB','GiB','TiB' (default is 'MiB')
