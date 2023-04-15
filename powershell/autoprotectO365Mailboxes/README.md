# Auto Protect O365 Mailboxes Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds mailboxes to an O365 protection job. New jobs will be created automatically so that all mailboxes will be protected and each job will have a maximum number of mailboxes based on the -maxMailboxesPerJob setting.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'autoprotectO365Mailboxes'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* autoprotectO365Mailboxes.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

To protect specific mailboxes:

```powershell
# example
./autoprotectO365Mailboxes.ps1 -vip mycluster `
                               -username myusername `
                               -domain mydomain.net `
                               -jobPrefix 'my o365 job '  
                               -policyName mypolicy `
                               -sourceName mydomain.onmicrosoft.com `
                               -maxMailboxesPerJob 2000
# end example
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

## Mandatory Parameters

* -jobPrefix: name of the O365 protection job to exclude mailboxes from
* -sourceName: name of registered O365 protection source (required for new job)
* -policyName: name of the protection policy to use (required for a new protection job)

## Optional Parameters

* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/Los_Angeles' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -disableIndexing: (optional) disable indexing (indexing is enabled by default)
* -maxMailboxesPerJob: (optional) default is 5000
