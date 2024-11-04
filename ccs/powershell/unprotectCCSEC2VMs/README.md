# Unprotect CCS EC2 VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script unprotects CCS EC2 VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectCCSEC2VMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectCCSEC2VMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/unprotectCCSEC2VMs/unprotectCCSEC2VMs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./unprotectCCSEC2VMs.ps1 -region us-east-2 `
                         -sourceName 121976284973 `
                         -vmName vm1, vm2 `
                         -deleteSnapshots
```

## Parameters

* -username: (optional) used for password storage only (default is 'CCS')
* -region: specify region (e.g. us-east-2)
* -sourceName: name of registered M365 protection source
* -vmName: (optional) one or more VM names to unprotect (comma separated)
* -vmList: (optional) text file of VM names to unprotect (one per line)
* -deleteSnapshots: (optional) delete existing snapshots

## Authenticating to CCS

CCS uses an API key for authentication. To acquire an API key:

* log onto CCS
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a CCS compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
