# Export Summary Report Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script exports a protection summary report to an Excel xlsx file. Note that the script only works on Windows and Excel must be installed.

## Components

* summaryReportXLSX.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/summaryReportXLSX/summaryReportXLSX.ps1).content | Out-File summaryReportXLSX.ps1; (Get-Content summaryReportXLSX.ps1) | Set-Content summaryReportXLSX.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/summaryReportXLSX/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

Place both files in a folder together and run the main script like so:

```powershell
./summaryReportXLSX.ps1 -vip mycluster -username myuser -domain mydomain.net

Connected!
Saving report to Z:\powershell\summaryReport-2019-06-25-13-05-59.xlsx...
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
