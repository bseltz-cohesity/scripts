# Expire Old Archives using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires archives older than x days. This is useful if you want to reduce your long term archive retention to reduce storage consumption in the cloud or other archive target.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

**Also Note**: If the archive target is out of space, please contact Cohesity support before running this script, otherwise expirations may not progress and will require support intervention.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'expireOldArchives'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [expireOldArchives.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expireOldArchives/expireOldArchives.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -expire switch to see what would be deleted.

```powershell
# example
./expireOldArchives.ps1 -vip mycluster -username myusername -domain mydomain.net -olderThan 120
# end example
```

Then, if you're happy with the list of archives that will be deleted, run the script again and include the -expire switch. THIS WILL DELETE THE OLD ARCHIVES!!!

```powershell
# example
./expireOldArchives.ps1 -vip mycluster -username myusername -domain mydomain.net -olderThan 120 -expire
# end example
```

To expire archives from only one specific target:

```powershell
# example
./expireOldArchives.ps1 -vip mycluster -username myusername -domain mydomain.net -target mytarget -olderThan 120 -expire
# end example
```

You can run the script again you should see no results.

Also note that data in the archive target may not be immediately deleted if a newer reference archive has not yet been created.

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) impersonate a multitenancy org
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) Name of protection job to expire archives from (default is all jobs)
* -target: (optional) narrow scope to a specific archive target
* -olderThan: (optional) show/expire snapshots older than this many days
* -newerThan: (optional) show/expire snapshots newer than this many days
* -expire: (optional) expire the snapshots (if omitted, the script will only show what 'would' be expired)
* -showUnsuccessful: (optional) just display unsuccessful archive runs
* -skipFirstOfMonth: (optional) do not expire archives that occured on the first day of the month
* -numRuns: (optional) page size for API call (default is 1000)
