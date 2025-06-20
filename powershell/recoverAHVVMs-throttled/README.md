# Recover multiple AHV VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a list of AHV VMs and limits the number of concurrent restores to the specified limit.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverAHVVMs-throttled'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverAHVVMs-throttled.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverAHVVMs-throttled/recoverAHVVMs-throttled.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./recoverAHVVMs-throttled.ps1 -vip mycluster `
                              -username myusername `
                              -domain mydomain.net `
                              -vmList ./vmlist.txt `
                              -prefix restore-
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
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -prefix: (optional) add a prefix to the VM name during restore
* -ahvSourceName: (optional) AHV protection source to recover to
* -networkName: (optional) VM Network to attach the VM to
* -storageContainer: (optional) storage container to recover the VM to
* -poweron: (optional) power on the VMs during restore (default is false)
* -detachNetwork: (optional) leave VM network disconnected (default is false)
* -vlan: (optional) vlan ID to choose for restore (cluster interface)
* -noPrompt: (optional) Don't prompt to confirm
* -maxConcurrentVMRestores: (optional) default is 10
* -recoveryType: (optional) InstantRecovery or CopyRecovery (default is InstantRecovery)
