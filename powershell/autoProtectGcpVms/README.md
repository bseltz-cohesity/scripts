# Autoprotect GCP VMs Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script finds and protects new unprotected VMs in Google Cloud Platform

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'autoProtectGcpVms'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [autoProtectGcpVms.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/autoProtectGcpVms/autoProtectGcpVms.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, and run the script like so:

```powershell
./autoProtectGcpVms.ps1 -vip mycluster `
                        -username myusername `
                        -domain mydomain.net `
                        -excludeProjects sbx, test `
                        -policy 'My Policy'
```

The script will identify any new, unprotected GCP VMs since the last time the script ran, and will add them to existing protection jobs or create new jobs (per project) and optionally send an email report. VM discoveries will also be logged in log-autoProtectGcpVms.txt.

## Basic Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -policy: name of protection policy to apply to new jobs

## Extra Parameters

* -excludeProjects: one or more substrings to exclude projects (commma separated)
* -reprotectOldVms: include old existing VMs
* -project: only process a specific project (default is all projects)
* -sendTo: email addresses to send report to (comma separated)
* -smtpServer: SMTP gateway to forward email through
* -smtpPort: SMTP port to use (default is 25)
* -sendFrom: email address to show in the from field

## Scheduling the Script to Run Using Windows Task Scheduler

Please review this PDF for tips on how to schedule PowerShell scripts using Windows task scheduler: <https://github.com/cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
