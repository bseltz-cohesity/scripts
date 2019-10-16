# Cohesity Running Job Monitor

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists running protection jobs. For each running job, the script will report:

* job name
* start time
* current task (local, archival, replication)
* state of current task

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/runningJobs/runningJobs.ps1).content | Out-File runningJobs.ps1; (Get-Content runningJobs.ps1) | Set-Content runningJobs.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/runningJobs/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* runningJobs.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./runningJobs.ps1 -vip mycluster -username admin -domain local
```

```text
Connected!

Running Jobs:
=============

Demo_Archive         10/16/19 12:58:05 PM   Local      Running
Demo_Archive         10/16/19 12:58:05 PM   Remote     Accepted
Demo_Archive         10/16/19 12:58:05 PM   Archival   Running
pb-sql               10/16/19 12:15:51 PM   Local      Running
pb-sql               10/16/19 12:15:51 PM   Remote     Accepted
Raja                 10/16/19 12:40:53 PM   Local      Running
Raja                 10/16/19 12:40:53 PM   Remote     Accepted

Output written to runningJobs.csv
```
