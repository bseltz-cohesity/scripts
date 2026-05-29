# Delete Local SQL Backups with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script deletes all local snapshots of a SQL server.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/expungeSQLBackups-date.txt

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deleteSQLBackups'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deleteSQLBackups.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/deleteSQLBackups/deleteSQLBackups.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./deleteSQLBackups.ps1 -vip mycluster `
                       -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -serverName sqlserver1.mydomain.net
```

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

* -serverName: (optional) one or more object names (comma separated)
* -serverList: (optional) text file with object names (one per line)
* -jobName: (optional) limit search to specific job name (default is all jobs)
* -olderThan: (optional) only delete snapshots/archives older than X days (defaults to 0)
* -delete: (optional) if omitted, script will only display what would be deleted
