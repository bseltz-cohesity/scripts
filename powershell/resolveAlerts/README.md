# Resolve Alerts using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists and resolves alerts.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'resolveAlerts'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [resolveAlerts.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/resolveAlerts/resolveAlerts.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

To list unresolved alerts

```powershell
./resolveAlerts.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net
```

To filter on a specific severity:

```powershell
./resolveAlerts.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -severity kCritical
```

To filter on a specific alertType:

```powershell
./resolveAlerts.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -alertType 1007
```

add -resolution to any of the above to mark them resolved:

```powershell
./resolveAlerts.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -alertType 1007 `
                    -resolution 'we solved this'
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

* -systemName: (optional) filter by cluster name
* -severity: (optional) filter on severity (kInfo, kCritical, etc.)
* -alertId: (optional) filter in specific alert ID
* -alertType: (optional) filter on alert type (1007, 1024, etc.)
* -alertCode: (optional) filter on alert code (CE00610022, etc.)
* -resolution: (optional) text to use for resolution (just report if omitted)
* -matchString: (optional) filter on matching string
* -startDate: (optional) include alerts after this date (e.g. '2022-08-01')
* -endDate: (optional) include alerts before this date (e.g. '2022-08-01')
* -maxDays: (optional) include alerts from the past X days
* -sortByDescription: (optional) sort screen output by alert description
