# Chart External Target Storage Growth Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Note: Please use the download commands below to download the script

This PowerShell script gathers storage usage statistics from an external target and charts them over time, using a JQuery Chart.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'externalTargetStorageChart'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [externalTargetStorageChart.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/externalTargetStorageChart/externalTargetStorageChart.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
# example
.\externalTargetStorageChart.ps1 -vip mycluster `
                                 -username myuser `
                                 -domain mydomain.net `
                                 -vaultName s3bucket1 `
                                 -days 100
# end example
```

Your browser should open and display the chart of storage growth.

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -vaultName: name of external target to inspect
* -days: number of days of storage statistics to display
