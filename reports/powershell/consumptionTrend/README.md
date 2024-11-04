# Report Storage Consumption Trends using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports per-job and per-view storage consumption trends. Output will be saved to an HTML report.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'consumptionTrend'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [consumptionTrend.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/consumptionTrend/consumptionTrend.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
./consumptionTrend.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -days 90 `
                       -rollup Monthly
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -days: (optional) number of days of statistics to collect (default is 31)
* -rollup: (optional) Daily, Weekly or Monthly (default is daily)
* -unit: = (optional) KiB, MiB, GiB or TiB (default is GiB)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
