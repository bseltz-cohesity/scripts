# Calculate View Growth Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Note: Please use the download commands below to download the script

This PowerShell script gathers the size of each view from X days util today and calculates the growth.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/viewGrowth/viewGrowth.ps1).content | Out-File viewGrowth.ps1; (Get-Content viewGrowth.ps1) | Set-Content viewGrowth.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [viewGrowth.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/viewGrowth/viewGrowth.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
# example
.\viewGrowth.ps1 -vip mycluster -username myuser -domain mydomain.net -days 31
# end example
```

Output will be saved to a .csv file.

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -days: (optional) number of days of storage statistics to collect (defaults to 31)
