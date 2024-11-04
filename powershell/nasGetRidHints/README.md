# Get NAS Rid Hints using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will gather replication ancestor hints from deleted NAS protection groups.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'nasGetRidHints'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* nasGetRidHints: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what snapshots would be modified. The parameters used below tell the script to check the past 14 days of snapshots (for all jobs) to see if any need adjusting. No changes will be made without the -commit parameter.

```powershell
./nasGetRidHints.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net
```

You can then apply the gflag change and perform the initial replication of the protected view, which will be incremental (0 bytes should be transferred during the initial replication).

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
