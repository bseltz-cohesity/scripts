# Protect a list of Cohesity Views using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates a protection job for each view listed in a text file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectViewList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectViewList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectViewList/protectViewList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectViewList.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -viewList ./viewlist.txt `
                      -policyName 'Standard Protection' `
                      -createDRview `
                      -drSuffix '-DR' `
                      -startTime '23:55' `
                      -timeZone 'America/New_York'
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -viewList: text file of view names to protect
* -policyName: name of protection policy to apply to the new job
* -startTime: (optional) e.g. 23:30 (default is 20:00)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -pause: leave the new job paused so it won't start
* -createDRview: (optional) create remote view during replication
* -drSuffix: (optional) e.g. '-DR'
