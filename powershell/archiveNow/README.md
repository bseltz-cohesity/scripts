# Archive Latest Snapshot using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script archives the oldest local snapshot that matches the specified criteria to an external target.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'archiveNow'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [archiveNow.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/archiveNow/archiveNow.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module [README](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api)

Place both files in a folder together, then we can run the script like so:

```powershell
./archiveNow.ps1 -vip mycluster `
                 -username myuser `
                 -domain mydomain.net `
                 -jobNames 'NAS Backup', 'SQL Backup' `
                 -vault s3 `
                 -keepFor 180 `
                 -commit
```

```text
Connected!
NAS Backup (04/18/2020 01:20:02) --> S3 (07/17/2020 01:20:02)
SQL Backup (04/17/2020 23:00:01) --> S3 (07/16/2020 23:00:01)
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -jobNames: one or more job names (comma separated)
* -vault: name of external target to archive to
* -vaultType: (optional) type of archive target (kCloud, kTape, kNas - defaults to kCloud)
* -dayOfYear: (optional) day of year for yearly snapshot (1 = Jan 1, -1 = Dec 31)
* -dayOfMonth: (optional) day of month for monthly snapshot (1 = 1st day of month, -1 = last day of month)
* -dayOfWeek: (optional) day of Week for weekly snapshot (e.g. Sunday)
* -firstOfMonth: (optional) only archive on the first dayOfWeek of the month (e.g. first Saturday)
* -runId: (optional) archive a specific job run ID
* -keepFor: number of days (from original backup date) to retain the archive
* -pastSearchDays: (optional) number of days back to seach for snapshots to archive (default is 31)
* -maxDrift: (optional) if snapshot failed on desired day, try the next X days (default is 3)
* -localOnly: (optional) archive only jobs local to this cluster
* -commit: (optional) execute the archive tasks (default is to show what would happen)

## Running and Scheduling PowerShell Scripts

For additional help running and scheduling Cohesity PowerShell scripts, please see [Running Cohesity PowerShell Scripts](https://github.com/bseltz-cohesity/scripts/blob/master/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf)
