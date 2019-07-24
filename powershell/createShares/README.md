# Create Cohesity Shares Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script creates shared folders within a view using a csv files as input. Note that share-level SMB permissions require Cohesity version 6.4 or later.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/createShares/createShares.ps1).content | Out-File createShares.ps1; (Get-Content createShares.ps1) | Set-Content createShares.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/createShares/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/createShares/shares.csv).content | Out-File shares.csv; (Get-Content shares.csv) | Set-Content shares.csv
# End Download Commands
```

## Components

* createShares.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module
* shares.csv: example shares file

Place both files in a folder together and run the main script like so:

```powershell
./createShares.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -shareDataFilename ./shares.csv `
                   -sourcePathPrefix '/ifs/myisilon/'
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -shareDataFilename: (optional) path to csv file
* -sourcePathPrefix: source path prefix to trim away
