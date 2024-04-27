# Set User Quotas using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script sets custom user quotas on a Cohesity View.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'setUserQuota'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [setUserQuota.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/setUserQuota/setUserQuota.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./setUserQuota.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -viewName myview `
                   -principal mydomain.net\myuser1, mydomain.net\myuser2 `
                   -quotaGiB 20
#end example
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: name of new view to create
* -principal: (optional) one or more AD users to set quotas for (comma separated)
* -principalList: (optional) text file containing AD users to set quotas for (one per line)
* -quotaGiB: quota for user in GiB
* -alertThreshold: (optional) percent full to alert (default is 85)
