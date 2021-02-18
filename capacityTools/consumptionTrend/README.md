# Report Storage Consumption Trends using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports per-job and per-view storage consumption trends.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'consumptionTrend'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/capacityTools/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* consumptionTrend.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
./consumptionTrend.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -days 90 `
                       -rollup Monthly
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -days: (optional) number of days of statistics to collect (default is 31)
* -rollup: Daily, Weekly or Monthly (default is daily)
