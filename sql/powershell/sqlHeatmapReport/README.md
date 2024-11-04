# Create a SQL Heatmap Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script will create a heatmap report for all protected SQL databases and send HTML output as an email attachment.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'sqlHeatmapReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [sqlHeatmapReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/sqlHeatmapReport/sqlHeatmapReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Example

```powershell
./sqlHeatMapReport.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -smtpServer 192.168.1.95 `
                       -sendFrom mycluster@mydomain.net `
                       -sendTo myuser@mydomain.net
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -timeZone: (optional) default is America/New_York
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
