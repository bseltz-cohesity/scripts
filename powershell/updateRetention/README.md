# Update Retention of Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will update the retention of snapshots to match the base retention of the policy that is associated with the protection job. Let's say you have your policy set to keep snapshots for 30 days, and then later you decide to change the policy to keep snapshots for 60 days or 14 days or whatever. The policy change will only affect future snapshots. If you want to adjust (extend or reduce) the retention of the existing snapshots, this script will query the policy and make the adjustments to all existing snapshots.

Warning: If used incorrectly, this script can expire old snapshots. Note that the script will set all snapshots to the base retention in the policy. It will not honor extended retention (e.g. weekly, monthly, etc). It's advisable to run the script without the -allowReduction and -commit parameters first and review the output before committing and changes.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateRetention'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* updateRetention: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what snapshots would be modified. The parameters used below tell the script to check the past 14 days of snapshots (for all jobs) to see if any need adjusting. No changes will be made without the -commit parameter.

```powershell
./updateRetention.ps1 -vip mycluster `
                      -username myuser `
                      -domain mydomain.net `
                      -newerThan 14
```

You can limit the query based on policy name(s):

```powershell
./updateRetention.ps1 -vip mycluster `
                      -username myuser `
                      -domain mydomain.net `
                      -policyNames 'my policy 1', 'my policy 2' `
                      -newerThan 14
```

Or you can limit the query based on job name(s):

```powershell
./updateRetention.ps1 -vip mycluster `
                      -username myuser `
                      -domain mydomain.net `
                      -jobNames 'my job 1', 'my job 2' `
                      -newerThan 14
```

When you are happy with the output, re-run the command and include the -commit parameter, like:

```powershell
./updateRetention.ps1 -vip mycluster `
                      -username myuser `
                      -domain mydomain.net `
                      -jobNames 'my job 1', 'my job 2' `
                      -newerThan 14 `
                      -commit
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -newerThan: (optional) Process backups no older than x days (default is 31)
* -policyNames: (optional) list of policy names (comma separated)
* -jobNames: (optional) list of job names (comma separated)
* -allowReduction: (optional) if omitted, no retentions will be shortened
* -commit: (optional) test run only if omitted
