# Extend Snapshots from the Nth WeekDay using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will extend the retention for the snapshots from the Nth (for example) Saturday of the month. Processed snapshots will be logged to extendLog.txt.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'extendNthWeekDay'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [extendNthWeekDay.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/extendNthWeekDay/extendNthWeekDay.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what would be extended / archived.

```powershell
./extendNthWeekDay.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -daysToKeep 90 `
                       -nth 1 `
                       -dayOfWeek Saturday
```

Then, if you're happy with the list of snapshots that will be processed, run the script again and include the -commit switch. This will execute the extension tasks.

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -nth: (optional) 1, 2, 3, 4 or -1 (default is 1)
* -dayOfWeek: (optional) default is Sunday
* -daysToKeep: retention days (from original backup date)
* -commit: (optional) perform extensions (otherwise test run only)

## Job Selection Parameters (default is all local jobs)

* -jobName: (optional) one or more job names (comma separated)
* -jobList: (optional) text file of job names (one per line)
* -policyName: (optional) one or more policy names (comma separated)
* -policyList: (optional) text file of policy names (one per line)
* -includeReplicas: (optional) extend snapshpts replicated to this cluster (default is local jobs only)

## Note

If `-policyName` or `-policyList` are used, then only local jobs can be processed.

To select the last occurence of a week day of the month, use `-nth -1`
