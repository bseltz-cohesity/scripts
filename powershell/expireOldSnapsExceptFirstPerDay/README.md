# Expire Old Snapshots (execpt the first one per day) using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/capacityTools/expireOldSnapsExceptFirstPerDay/expireOldSnapsExceptFirstPerDay.ps1).content | Out-File expireOldSnapsExceptFirstPerDay.ps1; (Get-Content expireOldSnapsExceptFirstPerDay.ps1) | Set-Content expireOldSnapsExceptFirstPerDay.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# end of download commands
```

## Components

* [expireOldSnapsExceptFirstPerDay.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expireOldSnapsExceptFirstPerDay/expireOldSnapsExceptFirstPerDay.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -expire switch to see what would be deleted.

```powershell
./expireOldSnapsExceptFirstPerDay.ps1 -vip bseltzve01 -username admin -daysToKeep 365
```

```text
Connected!
Searching for old snapshots...
VM Backup 11/29/2017 01:00:01
SQL VM Backup 11/29/2017 15:19:28
SQL VM Backup 11/29/2017 09:19:28
NAS Backup 11/29/2017 01:45:01
Infrastructure 11/29/2017 02:15:00
TestDB 11/29/2017 15:15:29
TestDB 11/29/2017 09:15:29
Oracle 11/28/2017 22:35:47
Oracle 11/28/2017 16:35:47
CorpShare 11/29/2017 04:07:00
```

Then, if you're happy with the list of snapshots that will be deleted, run the script again and include the -expire switch. THIS WILL DELETE THE OLD SNAPSHOTS!!!

```powershell
./expireOldSnapsExceptFirstPerDay.ps1 -vip bseltzve01 -username admin -daysToKeep 365 -expire
```

```text
Connected!
Searching for old snapshots...

Expiring VM Backup Snapshot from 11/29/2017 01:00:01
Expiring SQL VM Backup Snapshot from 11/29/2017 15:19:28
Expiring SQL VM Backup Snapshot from 11/29/2017 09:19:28
Expiring NAS Backup Snapshot from 11/29/2017 01:45:01
Expiring Infrastructure Snapshot from 11/29/2017 02:15:00
Expiring TestDB Snapshot from 11/29/2017 15:15:29
Expiring TestDB Snapshot from 11/29/2017 09:15:29
Expiring Oracle Snapshot from 11/28/2017 22:35:47
Expiring Oracle Snapshot from 11/28/2017 16:35:47
Expiring CorpShare Snapshot from 11/29/2017 04:07:00
```

You can run the script again you should see no results, unless the Cohesity cluster is very busy. It might take some time for the snapshots to actually be deleted.

Also note that if you're waiting for capacity to be freed up, it may take hours to days for the garbage collector to actually free up the space.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -jobname: (optional) narrow scope to just the specified job
* -daysToKeep: show/expire snapshots older than this many days
* -expire: (optional) expire the snapshots (if omitted, the script will only show what 'would' be expired)
