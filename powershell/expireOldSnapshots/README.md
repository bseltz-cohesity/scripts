# Expire Old Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires local snapshots older than x days. This is useful if you have reduced your on-prem retention and want to programatically expire local snapshots older than the new retention period.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'expireOldSnapshots'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [expireOldSnapshots.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expireOldSnapshots/expireOldSnapshots.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what would be deleted.

```powershell
./expireOldSnapshots.ps1 -vip mycluster `
                         -username myuser `
                         -domain mydomain.net `
                         -jobname myjob1, myjob2 `
                         -daysToKeep 14 `
```

Then, if you're happy with the list of snapshots that will be deleted, run the script again and include the -commit switch. THIS WILL DELETE THE OLD SNAPSHOTS!!!

```powershell
./expireOldSnapshots.ps1 -vip mycluster `
                         -username myuser `
                         -domain mydomain.net `
                         -jobname myjob1, myjob2 `
                         -daysToKeep 14 `
                         -commit
```

You can run the script again you should see no results, unless the Cohesity cluster is very busy. It might take some time for the snapshots to actually be deleted.

Also note that if you're waiting for capacity to be freed up, it may take hours to days for the garbage collector to actually free up the space.

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Basic Parameters

* -daysToKeep: (mandatory) show/expire snapshots older than this many days
* -reduceYoungerSnapshots: (optional) reduce retention of recent snapshots
* -commit: (optional) expire the snapshots (if omitted, the script will only show what 'would' be expired)
* -numRuns: (optional) page through X runs at a time (default is 1000)

## Filter Parameters

* -jobname: (optional) narrow scope to just the specified job(s) (comma separated)
* -backupType: (optional) choose one of kRegular, kFull, kLog or kSystem backup types (Default is kAll)
* -daysBack: (optional) narrow scope to just the last X days
* -skipWeeklies: (optional) don't change snapshots that are on the 1st day of the week (Sunday)
* -skipMonthlies: (optional) don't change snapshots that are on the 1st day of the month
* -skipYearlies: (optional) don't change snapshots that are on the 1st day of the year
* -localOnly: (optional) only process local protection groups
* -replicasOnly: (optional) only process replicated protection groups
* -skipIfNoReplicas: (optional) skip expiration if no replicas exist
* -skipIfNoArchives: (optional) skip expiration if no archives exist
