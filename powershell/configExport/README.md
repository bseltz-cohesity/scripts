# Export Cohesity Configuration Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases.

Note that re-importing objects is non-trivial and requires complex logic for each object type that depends on the use case and the specific situation.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'configExport'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* configExport.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./configExport.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -configFolder: (optional) Defaults to ./configExports

## Running as a Scheduled Task

Please see the following PDF for tips on running this script using Windows Task Scheduler:
<https://github.com/bseltz-cohesity/scripts/blob/master/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
