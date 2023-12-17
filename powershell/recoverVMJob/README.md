# Restore All VMs from a Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores all VMs from a Potection Job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverVMJob'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoverVMJob.ps1.ps1: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

```powershell
./recoverVMJob.ps1 -vip mycluster -username admin -jobName 'VM Backup' -vCenter vCenter1.mydomain.net -vmNetwork 'VM Network' -vmDatastore datastore1 -vmResourcePool pool1 -vmFolder myfolder
```

```text
Connected!
Restoring VMs...
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity logon username
* -domain: (optional) Cohesity logon domain (defaults to local)
* -jobName: Protection Job to recover
* -vCenter: vCenter protection source to recover to
* -vmNetwork: VM Network to attach the VMs to
* -vmDatastore: Datastore to recover the VMs to
* -vmResourcePool: (optional) Resource Pool to recover to
* -vmFolder: (optional) VM folder to recover to
