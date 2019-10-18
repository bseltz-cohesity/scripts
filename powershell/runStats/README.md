# Get Job Run Statistics Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to get statistics from job runs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'runStats'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* runStats.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./runStats.ps1 -vip 10.99.1.64 -username admin
Connected!
Collecting Job Run Statistics...
Runs for VMware Backups

Run Date             MB Read MB Written
--------             ------- ----------
11/17/18 11:05:54 AM      88          3
11/16/18 11:05:54 PM      85         10
11/16/18 11:05:54 AM      85         12
11/15/18 11:05:53 PM     109          1
11/15/18 11:05:53 AM     748         65
11/14/18 11:05:53 PM     690         95
11/14/18 11:05:53 AM    3240        124
11/13/18 11:05:53 PM     762         35
11/13/18 11:05:53 AM     678         14
11/12/18 11:05:52 PM     666         97
11/12/18 11:05:51 AM     983         31
11/11/18 11:05:50 PM     634         61
11/11/18 11:05:50 AM     732         60
11/10/18 11:05:49 PM     677        100
11/10/18 11:05:49 AM     643         42
```
