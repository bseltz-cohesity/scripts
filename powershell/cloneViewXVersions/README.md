# Maintain X Daily Clones of a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a View from X previous daily backups (or less if X days worth of backups are unavailable). The script will also delete a cloned view that is X+1 days old.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneViewXVersions'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* cloneViewXVersions.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module ([Get it Here...](../cohesity-api))

Place both files in a folder together and run the main script like so:

```powershell
./cloneViewXVersions.ps1 -vip mycluster -username myusername -domain mydomain.net -viewName myview -days 7
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -viewName: Name of the view to clone
* -days: (optional) number of daily versions of the view to clone (defaults to 7)
