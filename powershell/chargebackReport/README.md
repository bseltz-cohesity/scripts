# Generate a Chargeback Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script sends an HTML-formatted chargeback report, with an Excel attachment, to Email recipients. Note: this script only runs on Windows where Excel COM interface is available.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/chargebackReport/chargebackReport.ps1).content | Out-File chargebackReport.ps1; (Get-Content chargebackReport.ps1) | Set-Content chargebackReport.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/chargebackReport/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* chargebackReport.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./chargebackReport.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -amt 1 `
                 -sendTo myuser@mydomain.net, anotheruser@mydomain.net `
                 -smtpServer 192.168.1.95 `
                 -sendFrom backupreport@mydomain.net
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -amt: Cost per GB storage to assign
* -start: (optional) Start of date range (e.g. '2019-07-14') (defaults to 1 month ago)
* -end: (optional) End of date range (e.g. '2019-07-21') (defaults to today)
* -sendTo: email addresses to send report to (comma separated)
* -smtpServer: SMTP gateway to forward email through
* -smtpPort: SMTP port to use (default is 25)
* -sendFrom: email address to show in the from field
