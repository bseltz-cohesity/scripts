# Restore Ccs VMware VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a list of VMs from CCS.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreCcsVMWareVM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreCcsVMWareVM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/restoreCcsVMWareVM/restoreCcsVMWareVM.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To restore to the original location:

```powershell
./recoverVMs.ps1 -region us-east-2 `
                 -vmName myvm1, myvm2 `
                 -poweron `
                 -prefix restore-
```

Or to restore to an alternate location:

```powershell
./recoverVMs.ps1 -region us-east-2 `
                 -vmName myvm1, myvm2 `
                 -vCenterName myvcenter.mydomain.net `
                 -datacenterName mydatacenter `
                 -hostName esx1 `
                 -folderName myFolder `
                 -networkName 'VM Network' `
                 -datastoreName datastore1 `
                 -poweron `
                 -detachNetwork `
                 -prefix restore-
```

## Authentication Parameters

* -region: region for search and recovery (e.g. us-east-2)
* -username: (optional) used for password storage only (default is 'Ccs')
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password nor prompt for confirmation

## Basic Parameters

* -vmName: (optional) names of one or more VMs to recover (comma separated)
* -vmList: (optional) text file of VMs to recover (one VM per line)
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -prefix: (optional) add a prefix to the VM name during restore
* -overwrite: (optional) overwrite existing VM
* -poweron: (optional) power on the VMs during restore (default is false)
* -detachNetwork: (optional) leave VM network disconnected (default is false)
* -preserveMacAddress: (optional) maintain original Mac address (default is false)
* -taskName: (optional) name for recovery task

## Alternate Location Parameters

* -vCenterName: (optional)vCenter protection source to recover to
* -datacenterName: (optional) name of vSphere data center to recover to
* -hostName: (optional) name of vSphere host to recover to
* -folderName: (optional) name of vSphere folder to recover to
* -networkName: (optional) VM Network to attach the VM to
* -datastoreName: (optional) One or more datastore names to recover the VMs to (comma separated)

## Other Parameters

* -dbg: (optional) debug mode, export JSON payload to file for analysis
* -cacheFolder: (optional) folder to store cache files (default is '.')
* -maxCacheMinutes: (optional) refresh cached vCenter info after X minutes (default is 60)
* -noCache: (optional) do not cache vCenter info

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
