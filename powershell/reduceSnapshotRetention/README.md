# Reduce Snapshot Retention Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning

This script can expire existing backups. Please be sure you know what you are doing!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'reduceSnapshotRetention'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## How it works

This PowerShell script reduces the maximum snapshot retention to specified number of days. For each snapshot stored on the local cluster, if it's expiry time is more than X days from its start time, the snapshot's expiry time will be set to X days from its start time. If the new expiry time has passed, the snapshot will be expired.

By default, the script will make no changes and only display what it would do. To actually modify retentions and perform expirations, use the -force switch.

## Components

* reduceSnaphotRetention.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./reduceSnapshotRetention.ps1 -vip bseltzve01 -username admin -newRetention 45
Connected!
Reviewing snapshots...
Would reduce VM Backup 05/10/2019 11:00:05 by 23 days
Would reduce VM Backup 05/10/2019 10:00:05 by 23 days
Would reduce VM Backup 05/10/2019 09:00:05 by 23 days
```

Review the output. Once you are happy that the script would do what you want, run the script again using the -force switch.

```powershell
./reduceSnapshotRetention.ps1 -vip bseltzve01 -username admin -newRetention 45 -force
Connected!
Reducing retention for VM Backup Snapshot from 05/10/2019 10:00:05
Reducing retention for VM Backup Snapshot from 05/10/2019 09:00:05
Reducing retention for VM Backup Snapshot from 05/10/2019 08:00:06
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -newRetention: number of days (from original start time) to keep snapshots
* -jobName: (optional) operate on a specific job (default is all jobs)
* -force: (optional) actually perform snapshot modifications/expirations
