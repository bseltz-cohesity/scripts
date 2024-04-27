# Generate a Protection Details Per Object Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates a protection details per object report and writes the output to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosProtectionDetailsPerObject'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* heliosProtectionDetailsPerObject.ps1: the main python script ([raw code](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/helios/powershell/heliosProtectionDetailsPerObject/heliosProtectionDetailsPerObject.ps1))
* cohesity-api.ps1: the Cohesity REST API helper module ([raw code](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1))

Place both files in a folder together and run the main script like so:

```powershell
./heliosProtectionDetailsPerObject.ps1 -lastCalendarMonth
```

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -slurp: (optional) get stats for X objects per API call (default is 20)
* -pageCount: (optional) retrieve X pages of results (default is 6200)

## Date Range Parameters

* -startDate: (optional) explicit start date
* -endDate: (optional) explicit end date
* -thisCalendarMonth: (optional) use current month as date range
* -lastCalendarMonth: (optional) use last month as date range
* -days: (optional) number of days to include in report

## Scheduling the Script to run in Windows Task Scheduler

Please see info here <https://github.com//cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -updatePassword
Enter your password: *********************
```
