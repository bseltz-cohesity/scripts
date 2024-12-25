# Register an ESXi Host in CCS using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers an ESXi Host in CCS.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerESXiHostCCS'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerESXiHostCCS.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/registerESXiHostCCS/registerESXiHostCCS.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./registerESXiHostCCS.ps1 -connectionName 'My SaaS Connection' `
                          -esxiHostname myvcenter.mydomain.net `
                          -esxiUser administrator@vsphere.local
```

## Parameters

* -username: (optional) username to connect to Helios (default is 'Ccs')
* -password: (optional) API key to connect to Helios (will be prompted if omitted and not already stored)
* -connectionName: name of SaaS Connection to link vCenter
* -esxiHostname: name of vCenter to register
* -esxiUser: vCenter username to use for registration
* -esxiPassword: (optional) will be prompted if omitted
* -minFreeSpaceGiB: (optional) minimum free space in GiB to abort backups
* -minFreeSpacePct: (optional) minimum free space in percent to abort backups
* -maxStreams: (optional) throttle maximum number of concurrent backups

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
