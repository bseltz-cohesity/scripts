# Recover a VM using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a VM.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverVM'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoverVM.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./recoverVM.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -vmName myvm `
                -vCenter myvcenter.mydomain.net `
                -vmNetwork 'VM Network' `
                -vmDatastore datastore1 `
                -vmResourcePool resgroup1 `
                -vmFolder folder1 `
                -poweron `
                -disableNetwork `
                -recoverDate '2020-06-02 14:00' `
                -prefix restore- `
                -wait
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmName: Name of VM to recover
* -prefix: (optional) add a prefix to the VM name during restore
* -vCenter: vCenter protection source to recover to
* -vmNetwork: VM Network to attach the VMs to
* -vmDatastore: Datastore to recover the VMs to
* -vmResourcePool: (optional) Resource Pool to recover to
* -vmFolder: (optional) VM folder to recover to
* -poweron: (optional) power on the VMs during restore (default is false)
* -disableNetwork: (optional) leave VM network disconnected (default is false)
* -wait: (optional) wait for restore tasks to complete (default is false)
* -recoverDate: (optional) use point in time at or after date, e.g. '2019-10-01 23:30:00'
