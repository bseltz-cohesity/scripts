# Protect Ccs Physical Windows Servers using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects Ccs physcial Windows servers.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectCcsWindows'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectCcsWindows.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/protectCcsWindows/protectCcsWindows.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectCcsWindows.ps1 -region us-east-2 `
                        -sourceNames myserver1.mydomain.net, myserver2.mydomain.net `
                        -policyName Gold `
                        -inclusions 'c:\myfolder1', 'd:\myfolder2'
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -password: (optional) will be prompted if omitted and not already stored
* -region: specify region (e.g. us-east-2)
* -policyName: name of protection policy to use
* -sourceNames: (optional) one or more VM names to protect (comma separated)
* -sourceList: (optional) text file of VM names to protect (one per line)
* -inclusions: (optional) inclusion paths (comma separated)
* -inclusionList: (optional) a text file list of paths to include (one per line)
* -exclusions: (optional) one or more exclusion paths (comma separated)
* -exclusionList: (optional) a text file list of exclusion paths (one per line)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -pause: (optional) pause future runs
* -dbg: (optional) display JSON payload and exit

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
