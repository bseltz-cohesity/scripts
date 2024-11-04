# Change Retention of Local Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script will change (increase or decrease) the retention of existing snapshots. Note that if you reduce the retention, older backups might immediately get expired!

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'changeLocalRetention'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [changeLocalRetention.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/changeLocalRetention/changeLocalRetention.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what would be deleted.

```powershell
./changeLocalRetention.ps1 -vip mycluster `
                           -username myuser `
                           -domain mydomain.net `
                           -jobName 'My Job' `
                           -daysToKeep 10
```

To limit the protection groups to those whose names match the string 'VMs':

```powershell
./changeLocalRetention.ps1 -vip mycluster `
                           -username myuser `
                           -domain mydomain.net `
                           -jobMatch 'vms' `
                           -daysToKeep 10
```

If you're happy with the list of snapshots that will be changed, run the script again and include the -commit switch.

Warning: Any snapshots whose new expire date is set to a date in the past will expire immediately!

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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) narrow scope to just the specified jobs (comma separated)
* -jobList: (optional) text file of job names (one per line)
* -jobMatch: (optional) narrow scope to just jobs that match any of these strings (comma separated)
* -daysToKeep: set retention to X days from original run date
* -before: (optional) operate on runs before this date (e.g. '2022-10-10 00:00:00')
* -after: (optional) operate on runs after this date (e.g. '2022-09-01 23:00:00')
* -backupType: (optional) choose one of kRegular, kFull, kLog, kSystem. Default is AllExceptLogs
* -commit: (optional) perform the changes. If omitted, script will run in show/only mode
* -maxRuns: (optional) dig back in time for X snapshots. Default is 100000. Increase this value to get further back in time, decrease this parameter if the script reports an error that the response it too large
* -allowReduction: (optional) if omitted, the script will not reduce the retention of any snapshots
