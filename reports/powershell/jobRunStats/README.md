# Report Job Run Stats Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports protection job run statistics

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobRunStats'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [jobRunStats.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/jobRunStats/jobRunStats.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./jobRunStats.ps1 -vip mycluster -username myusername -domain mydomain.net
```

```text
Connected!
VM Backup (VMware)
    2/20/19 11:30:01 PM Success Regular 40 60.94 4.19
    2/19/19 11:30:01 PM Success Regular 40 62.81 5.36
    2/18/19 11:30:00 PM Success Regular 35 60.12 2.76
    2/17/19 11:30:00 PM Success Regular 36 62.81 0.42
    2/16/19 11:30:01 PM Success Regular 36 60.88 4.6
Infrastructure (VMware)
    2/20/19 11:40:01 PM Success Regular 154 3228.31 564.04
    2/19/19 11:40:01 PM Success Regular 143 3043.62 585.02
    2/18/19 11:40:01 PM Success Regular 139 2911.56 504.09
    2/17/19 11:40:01 PM Success Regular 163 3393.38 563.77
    2/16/19 11:40:00 PM Success Regular 211 4553.62 939.96
SQL Backup (SQL)
    2/21/19 3:04:47 AM Success Log 10 0.23 0.01
    2/21/19 12:20:00 AM Success Regular 70 394.06 68.18
    2/20/19 9:04:47 PM Success Log 8 0.17 0
    2/20/19 3:04:47 PM Success Log 8 0.17 0
    2/20/19 9:04:46 AM Success Log 8 0.17 0
...
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) password or API key (will use stored password by default)
* -mfaCode: (optional) multi-factor authentication code
* -emailMfaCode: (optional) send mfaCode via email
* -failedOnly: (optional) Show only unsuccessful job runs
* -lastDay: (optional) Show only the past 24 hours of job runs
* -numDays: (optional) Limit output to the last X days

Stats are also output to a csv file for further review.
