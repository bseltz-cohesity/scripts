# Email Backup Strike Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script sends an HTML-formatted backup strike report to Email recipients

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'strikeReport-multi'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [strikeReport-multi.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/strikeReport-multi/strikeReport-multi.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./strikeReport-multi.ps1 -vips mycluster1, mycluster2 `
                         -username myusername `
                         -domain mydomain.net `
                         -sendTo myuser@mydomain.net, anotheruser@mydomain.net `
                         -smtpServer 192.168.1.95 `
                         -sendFrom backupreport@mydomain.net
```

## Parameters

* -vips: Cohesity Clusters to connect to (comma separated)
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendFrom: (optional) email address to show in the from field
* -days: (optional) number of days of history (default is 31)
* -slurp: (optional) number of runs to parse per api call (default is 100) reduce to solve for JSON response too large errors
* -failureCount: (optional) report only if failure count is equal or greater than X (default is 1)
