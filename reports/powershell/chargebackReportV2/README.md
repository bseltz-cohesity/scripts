# Email Chargeback Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script sends a TSV formatted chargeback report to Email recipients

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'chargebackReportV2'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [chargebackReportV2.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/chargebackReportV2/chargebackReportV2.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example command
./chargebackReportV2.ps1 -vip mycluster `
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

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -costPerGB: (optional) Cost per GB per date range (e.g. per month) default is 1.00
* -numRuns: (optional) number of runs per API query (default is 500)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
