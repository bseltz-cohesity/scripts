# Backup Now and Copy Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will enable a disabled job to run it, and disable it when done.

## Components

* backupNowAndCopy.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./backupNowAndCopy.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -replicateTo myothercluster -keepReplicaFor 10
```
```text
Connected!
Running My Job...
```

## Optional Parameters

*  -archiveTo: (optional) name of archival target to archive to
*  -keepArchiveFor: days to keep in archive (default is 5 days)
*  -replicateTo: (optional) name of remote cluster to replicate to
*  -keepReplicaFor: days to keep replica for (default is 5 days)

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/backupNowAndCopy/backupNowAndCopy.ps1 -OutFile backupNowAndCopy.ps1
Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/backupNowAndCopy/cohesity-api.ps1 -OutFile cohesity-api.ps1
```

