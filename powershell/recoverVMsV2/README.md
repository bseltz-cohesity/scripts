# Recover multiple VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a list of VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverVMsV2'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoverVMsV2.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./recoverVMsV2.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -vmList ./vmlist.txt `
                   -vCenterName myvcenter.mydomain.net `
                   -datacenterName mydatacenter `
                   -hostName esx1 `
                   -folderName myFolder `
                   -networkName 'VM Network' `
                   -datastoreName datastore1 `
                   -poweron `
                   -detachNetwork `
                   -prefix restore- `
                   -recoveryType InstantRecovery
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -tenant: (optional) tenant name to impersonate
* -vmList: text file of vms to recover (one VM per line)
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -prefix: (optional) add a prefix to the VM name during restore
* -vCenterName: (optional)vCenter protection source to recover to
* -datacenterName: (optional) name of vSphere data center to recover to
* -hostName: (optional) name of vSphere host to recover to
* -folderName: (optional) name of vSphere folder to recover to
* -networkName: (optional) VM Network to attach the VM to
* -datastoreName: (optional) Datastore to recover the VM to
* -poweron: (optional) power on the VMs during restore (default is false)
* -detachNetwork: (optional) leave VM network disconnected (default is false)
* -preserveMacAddress: (optional) maintain original Mac address (default is false)
* -recoveryType: (optional) InstantRecovery or CopyRecovery (default is InstantRecovery)
