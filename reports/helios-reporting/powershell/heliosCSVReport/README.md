# Generate Helios CSV Reports using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates helios reports and outputs CSV format.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosCSVReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-reporting/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* heliosCSVReport.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./heliosCSVReport.ps1 -username myusername@mydomain.net -reportName 'Storage Consumption by Objects'
```

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -startDate: (optional) specify start of date range
* -endDate: (optional) specify end of date range
* -thisCalendarMonth: (optional) set date range to this month
* -lastCalendarMonth: (optional) set date range to last month
* -days: (optional) set date range to last X days (default is 7)
* -reportName: name of Helios report to generate
* -dayRange: (optional) page results by number of days (default is 7)
* -clusterNames: (optional) limit report to one or more cluster names (comma separated)
* -timeZone: (optional) default is 'America/New_York',
* -outputPath: (optional) path to write output files (default is '.')
* -includeCCS: (optional) include CCS region data
* -excludeLogs: (optional) skip backup type kLog
* -environment: (optional) one or more (comma separated) environments to include (e.g. kSQL, kO365)
* -excludeEnvironment: (optional) one or more (comma separated) environments to exclude (e.g. kSQL, kO365)
* -replicationOnly: (optional) filter protection activities report to show replication tasks only
* -timeoutSeconds: (optional) time to wait for API response before timeout (default is 600)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon (settings) -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -username myusername@mydomain.net -updatePassword
Enter your password: *********************
```
