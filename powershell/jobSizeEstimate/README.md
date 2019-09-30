# Estimate Job Space Consumption Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script attempts to calculate the post-dedup space consumption of a protection job. Note that the results are most likely wildly inaccurate, but may still be useful for for sizing and storage consumption analysis.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobSizeEstimate'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* jobSizeEstimate.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
.\jobSizeEstimate.ps1 -vip mycluster -username myuser -domain mydomain.net -jobName 'SQL Backup'
Connected!

Job Consumption for job: SQL Backup

   Logical Size MB: 71680
       Dedup Ratio: 3.29
Compressed Size MB: 21787
    Incremental MB: 229
          Total MB: 22016
          Total GB: 21.5

```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
* -jobName: name of protection job to evaluate
* -recentFirstFull: (optional) avoid double-counting first full if it is still in retention
* -fullFactor: (optional) estimated percent full for VM and physical volume-based jobs (e.g. 50)
