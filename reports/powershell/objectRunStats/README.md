# Get Object Run Stats using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script gets object run stats and writes out to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'objectRunStats'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [objectRunStats.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/objectRunStats/objectRunStats.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./objectRunStats.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -jobName 'my job' `
                     -objectName server1.mydomain.net
```

```text
Connected!
Gathering Stats from the following dates:
  08/22/2020 01:00:00
  08/21/2020 01:00:00
  08/20/2020 01:00:00
  08/19/2020 01:00:00
  08/18/2020 01:00:00
Output saved to /Users/brianseltzer/scripts/powershell/objectRunStats-my job-server1.mydomain.net.csv
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -password: (optional) will be prompted if omitted, then saved for future use
* -jobName: name of protection job/group
* -objectName: name of server/nas volume
