# Distributed Backups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script is a customized solution for a specific use case, where a massive file share (with billions of files), hosted on Compellent NAS with multiple NAS heads, needed to be split up at the folder level across the NAS heads. If there's a need to use this type of script, please engage your Cohesity team for customization.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'distributeBackups'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* distributeBackups: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./distributeBackups.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobName MYJOB `
                        -nasShares \\nas1\myshare, \\nas2\myshare, \\nas3\myshare `
                        -policyName 'Local Only' `
                        -inputFile ./folders.csv `
                        -jobMultiplier 1
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -jobName: Job name (prefix)
* -nasShares: list of registered mount points to protect
* -policyName: policy name to apply to jobs
* -inputFile: CSV file containing folder names and object counts
* -jobMultiplier: (optional) number of jobs per NAS head
* -storageDomain: (optional) defaults to DefaultStorageDomain
* -timeZone: (optional) defaults to America/New_York
* -startHour: (optional) defaults to 20 (8PM)
