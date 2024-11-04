# Show Job Object Adds and Removals over time using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script reports added and deleted objects from one job run to the next, across runs that are in retention. Output is written to a text file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobObjectHistory'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [jobObjectHistory.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/jobObjectHistory/jobObjectHistory.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./jobObjectHistory.ps1 -vip mycluster -username myusername -domain mydomain.net
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -days: (optional) default is 7 days
* -ignoreAdds: (optional) do not report adds
* -ignoreRemoves: (optional) do not report removals
* -smtpServer: (optional) SMTP server to send email reports to
* -smtpPort: (optional) SMTP port for email (default is 25)
* -sendTo: (optional) comma separated list of email addresses to send report to
* -sendFrom: (optional) email address to send reports from
