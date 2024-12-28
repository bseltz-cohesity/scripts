# Protect Ccs M365 Teams using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects Ccs M365 Teams.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectCcsVMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectCcsVMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/protectCcsVMs/protectCcsVMs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectCcsVMs.ps1 -region us-east-2 `
                    -sourceName myvcenter.mydomain.net `
                    -policyName Gold `
                    -vmNames vm1, vm2
```

To autop-protect a source (only for sources of type standalone host):

```powershell
./protectCcsVMs.ps1 -region us-east-2 `
                    -sourceName myvcenter.mydomain.net `
                    -policyName Gold `
                    -autoProtectSource `
                    -excludeVmNames vm3, vm4
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -password: (optional) will be prompted if omitted and not already stored
* -region: specify region (e.g. us-east-2)
* -sourceName: name of registered vCenter/ESXi host source
* -policyName: name of protection policy to use
* -vmNames: (optional) one or more VM names to protect (comma separated)
* -vmList: (optional) text file of VM names to protect (one per line)
* -excludeVmNames: (optional) one or more VM names to exclude (comma separated)
* -excludeVmList: (optional) text file of VM names to exclude (one per line)
* -autoProtectSource: (optional) auto-protect the specified source (only for soures of type Standalone Host)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -pause: (optional) pause future runs
* -listEntities: (optional) list indexed entities
* -entityType: (optional) list indexed entities of this type only (e.g. kFolder)
* -dbg: (optional) disply JSON payload and exit

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
