# VM Protection Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell generates a VM protection report.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'vmProtectionReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [vmProtectionReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/vmProtectionReport/vmProtectionReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./vmProtectionReport.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -parentSourceName myvcenter.mydomain.net `
                         -unProtected
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -parentSourceName: (optional) protection source name of parent (vCenter/Cloud Subscription, etc.)
* -parentSourceId: (optional) protection source ID of parent (vCenter/Cloud Subscription, etc.)
* -protected: (optional) only show protected VMs
* -unProtected: (optional) only show unprotected VMs
