# Email Chargeback Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script sends an HTML-formatted chargeback report to Email recipients

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'chargebackReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [chargebackReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/chargebackReport/chargebackReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example command
./chargebackReport.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -prefix demo,test `
                       -costPerGB 0.10 `
                       -sendTo myuser@mydomain.net, anotheruser@mydomain.net `
                       -smtpServer 192.168.1.95 `
                       -sendFrom backupreport@mydomain.net
# end example
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

* -prefix: job name prefixes to include in the report (comma separated, defaults to all jobs if omitted)
* -costPerGB: Cost per GB per date range (e.g. per month)
* -numRuns: number of runs per API query (default is 1000)
* -sendTo: email addresses to send report to (comma separated)
* -smtpServer: SMTP gateway to forward email through
* -smtpPort: SMTP port to use (default is 25)
* -sendFrom: email address to show in the from field

## Date Range Parameters

If no date range parameters are specified, the date range will default to the last 31 days. Otherwise you can use one of the following:

* -lastXdays: (optional) the range will be from X days ago to today (e.g. -lastXdays 14)

or

* -lastCalendarMonth: (optional) the range will be from the first day of last month to the first day of this month.

or

* -startDate: (optional) start of date range to report on (e.g. -startDate '2019-08-01')
* -endDate: (optional) end of date range to report on (e.g. -endDate '2019-09-01')

Keep in mind that if your date range is older than your backup retention, object sizes will be returned as 0!
