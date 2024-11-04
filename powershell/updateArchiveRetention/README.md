# Update Retention of Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will update the retention of existing archives. Note that for Cohesity versions prior to 6.5.1b, the local snapshots must still exist for archive retention to be modified.

Warning: If used incorrectly, this script can expire archives. It's advisable to run the script without the -allowReduction and -commit parameters first and review the output before committing and changes.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateArchiveRetention'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* updateArchiveRetention: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what snapshots would be modified. The parameters used below tell the script to check the past 14 days of snapshots (for all jobs) to see if any need adjusting. No changes will be made without the -commit parameter.

```powershell
./updateArchiveRetention.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -daysToKeep 90
```

You can limit the query based on policy name(s):

```powershell
./updateArchiveRetention.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -policyNames 'my policy 1', 'my policy 2' `
                             -daysToKeep 90
```

Or you can limit the query based on job name(s):

```powershell
./updateArchiveRetention.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -jobNames 'my job 1', 'my job 2' `
                             -daysToKeep 90
```

When you are happy with the output, re-run the command and include the -commit parameter, like:

```powershell
./updateArchiveRetention.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -jobNames 'my job 1', 'my job 2' `
                             -daysToKeep 90
                             -commit
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -target: (optional) Limit operations to specific external target
* -daysToKeep: number of days (from original backup date) to retain archives
* -policyNames: (optional) list of policy names (comma separated)
* -jobNames: (optional) list of job names (comma separated)
* -allowReduction: (optional) if omitted, no retentions will be shortened
* -commit: (optional) test run only if omitted
