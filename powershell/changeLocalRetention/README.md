# Change Retention of Local Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'changeLocalRetention'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* changeLocalRetention.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -force switch to see what would be deleted.

```powershell
./changeLocalRetention.ps1 -vip mycluster `
                           -username myuser `
                           -domain mydomain.net `
                           -jobname 'My Job' `
                           -snapshotDate '2020-05-01 23:30' `
                           -daysToKeep 10
```

```text
Connected!
Changing retention for VM Backup (05/01/2020 23:30:01) to 05/11/2020 23:30:01
```

If you're happy with the list of snapshots that will be changed, run the script again and include the -force switch.

Warning: Any snapshots whose new expire date is set to a date in the past will expire immediately!

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -jobname: (optional) narrow scope to just the specified jobs (comma separated)
* -daysToKeep: set retention to X days from original run date
* -snapshotDate (optional) specify run date to monify (e.g. '2020-04-30' or '2020-04-30 23:00' or '2020-04-30 23:00:02')
* -backupType: (optional) choose one of kRegular, kFull, kLog or kSystem backup types. Default is all
* -force: (optional) perform the changes. If omitted, script will run in show/only mode
* -maxRuns: (optional) dig back in time for X snapshots. Default is 100000. Increase this value to get further back in time, decrease this parameter if the script reports an error that the response it too large
