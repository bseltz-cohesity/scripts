# Backup Now and Wait Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to fimish and report the end status of the job.

## Components

* backupNowAndWait.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./backupNowAndWait.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -keepLocalFor 7 -replicateTo anothercluster -keepReplicaFor 10 -backupType kRegular
```

```text
Connected!
Running My Job...
Job finished with status: kSuccess
```

## Optional Parameters

* -keepLocalFor: days to keep local snapshot (default is 5 days)
* -archiveTo: (optional) name of archival target to archive to
* -keepArchiveFor: days to keep in archive (default is 5 days)
* -replicateTo: (optional) name of remote cluster to replicate to
* -keepReplicaFor: days to keep replica for (default is 5 days)
* -enable: (optional) enable a paused job before running, then disable when done
* -backupType: (optional) choose one of kRegular, kFull or kLog backup types. Default is kRegular (incremental)

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/backupNowAndWait/backupNowAndWait.ps1).content | Out-File backupNowAndWait.ps1; (Get-Content backupNowAndWait.ps1) | Set-Content backupNowAndWait.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/backupNowAndWait/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```
