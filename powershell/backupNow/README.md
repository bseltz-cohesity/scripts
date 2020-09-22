# Backup Now Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to fimish and report the end status of the job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backupNow'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* backupNow.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./backupNow.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -jobName 'My Job' `
                -keepLocalFor 7 `
                -replicateTo anothercluster `
                -keepReplicaFor 10 `
                -backupType kRegular
```

```text
Connected!
Running My Job...
Job finished with status: kSuccess
```

## Parameters

* -vip: DNS or IP of the Cohesity Cluster
* -username: Cohesity User Name
* -domain: - defaults to 'local'
* -useApiKey: Use API key for authentication
* -jobName: name of protection job to run
* -usePolicy: use base retention and copy targets from protection policy
* -keepLocalFor: days to keep local snapshot (default is 5 days)
* -archiveTo: name of archival target to archive to
* -keepArchiveFor: days to keep in archive (default is 5 days)
* -replicateTo: name of remote cluster to replicate to
* -keepReplicaFor: days to keep replica for (default is 5 days)
* -enable: enable a paused job before running, then disable when done
* -backupType: choose one of kRegular, kFull, kLog or kSystem backup types. Default is kRegular (incremental)
* -objects: comma separated list of object names to include in the job run. For VMs, simply include the VM name. For SQL databases, object names should be in the form of server.mydomain.net/instanceName/dbName. For Oracle databases, object names should be in the form of server.mydomain.net/dbName
* -progress: display percent complete
* -wait: wait for job to complete and return exit code, otherwise exit immediately after starting the job
