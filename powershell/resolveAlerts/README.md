# Resolve Alerts using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists and resolves alerts.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'resolveAlerts'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* resolveAlerts.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

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

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -severity: filter on severity (kInfo, kCritical, etc.)
* -alertType: filter on alert type (1007, 1024, etc.)
* -resolution: text to use for resolution (just report if omitted)
