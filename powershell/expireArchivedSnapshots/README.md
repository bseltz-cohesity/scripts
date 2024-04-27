# Expire Archived Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires local snapshots that have been archived. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots that have been archived and are older than the new retention period.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'expireArchivedSnapshots'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [expireArchivedSnapshots.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expireArchivedSnapshots/expireArchivedSnapshots.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -expire switch to see what would be deleted.

```powershell
./expireArchivedSnapshots.ps1 -vip mycluster -username admin -olderThan 365
```

```text
Connected!
searching for old snapshots...
found 6 snapshots with archive tasks
To Expire 12/02/2017 05:22:13  CorpShare  (Archive kSuccessful)
To Expire 12/02/2017 11:24:02  Infrastructure  (Archive kSuccessful)
To Expire 12/02/2017 11:26:07  VM Backup  (Archive kSuccessful)
To Expire 12/03/2017 00:50:00  Infrastructure  (Archive kSuccessful)
To Expire 12/03/2017 01:00:00  VM Backup  (Archive kSuccessful)
To Expire 12/03/2017 02:10:00  CorpShare  (Archive kSuccessful)
```

Then, if you're happy with the list of snapshots that will be deleted, run the script again and include the -expire switch. THIS WILL DELETE THE OLD SNAPSHOTS!!!

```powershell
./expireArchivedSnapshots.ps1 -vip mycluster -username admin -olderThan 365 -expire
```

```text
Connected!
searching for old snapshots...
found 6 snapshots with archive tasks
Expiring  12/02/2017 05:22:13  CorpShare  (Archive kSuccessful)
Expiring  12/02/2017 11:24:02  Infrastructure  (Archive kSuccessful)
Expiring  12/02/2017 11:26:07  VM Backup  (Archive kSuccessful)
Expiring  12/03/2017 00:50:00  Infrastructure  (Archive kSuccessful)
Expiring  12/03/2017 01:00:00  VM Backup  (Archive kSuccessful)
Expiring  12/03/2017 02:10:00  CorpShare  (Archive kSuccessful)
```

You can run the script again you should see no results, unless the Cohesity cluster is very busy. It might take some time for the snapshots to actually be deleted.

Also note that if you're waiting for capacity to be freed up, it may take hours to days for the garbage collector to actually free up the space.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -jobName: (optional) Name of protection job to expire archives from (default is all jobs)
* -olderThan: show/expire snapshots older than this many days
* -expire: (optional) expire the snapshots (if omitted, the script will only show what 'would' be expired)
