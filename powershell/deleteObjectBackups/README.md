# Delete Local Object Backups with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script searches for a protected object, and deletes all local snapshots of that object.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/deleteObjectBackupsLog-date.txt

## Download the Script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deleteObjectBackups'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deleteObjectBackups.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deleteObjectBackups/deleteObjectBackups.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./deleteObjectBackups.ps1 -vip mycluster -username myusername -domain mydomain.net -objectName myvm
```

First, run the script WITHOUT the -delete switch to see what would be deleted. When you are happy for the script to actually delete what was displayed, rerun the command with the -delete switch

Please note that there may be some delay before the deletions are reflected in subsequent script run output.

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -objectName: (optional) one or more object names (comma separated)
* -objectList: (optional) text file with object names (one per line)
* -objectMatch: (optional) search string for patial name match (e.g. 'indows')
* -jobName: (optional) limit search to specific job name (default is all jobs)
* -olderThan: (optional) only delete snapshots/archives older than X days (defaults to 0)
* -delete: (optional) if omitted, script will only display what would be deleted
