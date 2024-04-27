# Gather Cloud Archive Direct Size and Transfer Stats

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script gathers cloud archive direct size and transfer stats.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloudArchiveDirectStats'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloudArchiveDirectStats.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/cloudArchiveDirectStats/cloudArchiveDirectStats.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./cloudArchiveDirectStats.ps1 -vip mycluster -username myusername -domain mydomain.net
```

The output will be written to a CSV file.

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -unit: (optional) MiB, GiB or TiB (default is MiB)
* -startDate: (optional) show run dates on or after this date (e.g. '1/21/2021' or '1/21/2021 23:59:05')
* -endDate: (optional) show run dates on or before this date (e.g. '1/21/2021' or '1/21/2021 23:59:05')
