# Report Job Run Duration Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports protection job run duration and data read over the past 24 hours

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobRunDuration'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [jobRunDuration.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/jobRunDuration/jobRunDuration.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./jobRunDuration.ps1 -vip mycluster -username myusername -domain mydomain.net
```

```text
Connected!
VM Backup      2/23/20 11:00:00 PM  42 seconds  69.81 MB read
Oracle Backup  2/23/20 11:40:00 PM  49 seconds  3771.32 MB read
Infrastructure 2/24/20 12:00:00 AM  309 seconds 6907.94 MB read
SQL Backup     2/24/20 9:08:26 AM   17 seconds  1 MB read
SQL Backup     2/24/20 9:07:59 AM   15 seconds  0.44 MB read
SQL Backup     2/24/20 7:36:35 AM   19 seconds  1.5 MB read
SQL Backup     2/24/20 6:49:24 AM   17 seconds  69.62 MB read
SQL Backup     2/23/20 11:00:00 PM  21 seconds  1.56 MB read
NAS Backup     2/24/20 1:20:02 AM   8 seconds   0.14 MB read
Scripts Backup 2/24/20 1:19:01 PM   0 seconds   0 MB read
File-based Linux  2/24/20 4:14:00 AM   17 seconds   5.56 MB read
nastest        2/24/20 11:45:22 AM  6 seconds   0 MB read
Output written to jobRunDuration-2-24-20_4-53-53_PM.csv
...
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
* -jobNames: comma separated list of job names to include (defaults to all jobs if omitted)

Stats are also output to a csv file for further review.
