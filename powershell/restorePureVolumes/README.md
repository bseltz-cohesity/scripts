# Restore Pure Volumes from Cohesity using Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script restores Pure Storage volumes from a Cohesity backup.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restorePureVolumes'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* restorePureVolumes.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module ([README](https://github.com/bseltz-cohesity/scripts/tree/master/powershell/cohesity-api))

Place both files in a folder together and run the main script like so:

```powershell
# example
./restorePureVolumes.ps1 -vip mycluster -username myusername -pureName mypure -volumeName myserver_lun1, myserver_lun2 -prefix 'restore-' -suffix '-0410'
# end example
```

```text
Connected!
Restoring mypure/myserver_lun1 as mypure/restore-myserver_lun1-0410
Restoring mypure/myserver_lun2 as mypure/restore-myserver_lun2-0410
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -pureName: name of registered pure array
* -volumeName: volume name(s) to recover (comma separated)
* -volumeList: text file with volume names to recover
* -prefix: prefix to apply to recovered volumes
* -suffix: suffix to apply to recovered volumes
