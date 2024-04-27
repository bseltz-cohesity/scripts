# Report Latest Status of Protected Objects using PowerShell (multi-cluster)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script reports the latest backup status of protected objects across multiple clusters. The output will be written to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'dailyObjectStatus-multi'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [dailyObjectStatus-multi.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/dailyObjectStatus-multi/dailyObjectStatus-multi.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./dailyObjectStatus-multi.ps1 -vips mycluster1, mycluster2, mycluster3 `
                              -username myusername ` 
                              -domain mydomain.net
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -yesterdayOnly: (optional) only include yesterday 12AM to today 12AM (by default yesterday 12AM to now is included)
* -filters: (optional) only show jobs that match any of the specified search strings (e.g. -filters prod, dev, test)
