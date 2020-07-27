# Replicate Old Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script replicates existing local snapshots to a replication target. This is useful if you have recently created an replication target and want to programatically replicate existing local snapshots.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'replicateOldSnapshots'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* replicateOldSnapshots.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -replicate switch to see what would be replicated.

```powershell
./replicateOldSnapshots.ps1 -vip mycluster -username admin -replicateTo CohesityVE -olderThan 1 -IfExpiringAfter 3
```

```text
Connected!
searching for old snapshots...
05/19/2019 23:20:00  VM Backup  (expiring in 3 days. skipping...)
05/20/2019 05:34:46  VM Backup  (expiring in 3 days. skipping...)
05/20/2019 23:20:00  VM Backup  (would replicate for 4 days)
05/19/2019 23:40:01  Infrastructure  (expiring in 3 days. skipping...)
05/20/2019 23:40:01  Infrastructure  (would replicate for 4 days)
05/20/2019 00:00:01  Oracle Adapter  (expiring in 3 days. skipping...)
05/21/2019 00:00:01  Oracle Adapter  (would replicate for 4 days)
05/20/2019 00:20:00  SQL Backup  (expiring in 3 days. skipping...)
05/21/2019 00:20:01  SQL Backup  (would replicate for 4 days)
```

Then, if you're happy with the list of snapshots that will be replicated, run the script again and include the -replicate switch. This will execute the replication tasks

```powershell
./replicateOldSnapshots.ps1 -vip mycluster -username admin -replicateTo CohesityVE -olderThan 1 -IfExpiringAfter 3 -replicate
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: AD domain name (defaults to local)
* -jobName: (optional) replicate only specified job (otherwise replicate all jobs)
* -replicateTo: name of remote cluster to replicate to
* -keepFor: days to keep replica (default is same as local) existing age is subtracted
* -olderThan: (optional) only replicate if older than X days
* -IfExpiringAfter: (optional) only replicate if there are X or more days left before expiration
* -replicate: actually replicate (otherwise only a test run)
