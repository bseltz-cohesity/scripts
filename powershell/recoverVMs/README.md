# Recover multiple VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a list of VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverVMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverVMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverVMs/recoverVMs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./recoverVMs.ps1 -vip mycluster `
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

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -vmName: (optional) names of one or more VMs to recover (comma separated)
* -vmList: (optional) text file of VMs to recover (one VM per line)
* -vmTag: (optional) recover all VMs that have this VMware Tag
* -protectionGroup: (optional) recover all VMs from this protection group
* -jobName: (optional) recover VMs from this protection group only
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
* -vlan: (optional) vlan ID to choose for restore (cluster interface)
* -noPrompt: (optional) Don't prompt to confirm
* -taskName: (optional) name for recovery task
* -dbg: (optional) debug mode, export JSON payload to file for analysis
* -overwrite: (optional) overwrite existing VM

Note: when restoring to a standalone ESXi host, review the object hierarchy of the registered ESXi host under protection sources to determine the following information, but typically:

* -datacenterName is 'ha-datacenter'
* -folderName is 'vm'
* -vCenterName is the registered source name of the ESXi host
* -hostName is the registered source name of the ESXi host

## Specifying a Folder

You can specify a folder to restore to using any of the following formats:

* /vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* /MyFolder/MySubFolder
* MyFolder/MySubFolder
