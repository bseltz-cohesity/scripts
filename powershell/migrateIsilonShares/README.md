# Migrate Isilon Shares to Cohesity Views Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script takes SMB share information from isilon, and for each share, identifies the matching subdirectory on the specified Cohesity view, and migrates share permissions and child shares. Note that share-level SMB permissions require Cohesity version 6.4 or later.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateIsilonShares'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateIsilonShares.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/migrateIsilonShares/migrateIsilonShares.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./migrateIsilonShares.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -isilon myisilon `
                          -isilonUsername admin `
                          -viewName isilon `
                          -sourcePath /ifs
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -isilon: name of isilon to connect to
* -isilonUsername: name of isilon user
* -isilonPassword: (optional) password to connect to isilon
* -viewName: name of Cohesity view that isilon was restored to
* -sourcePath: isilon path that was restored to the Cohesity view (e.g. /ifs)
