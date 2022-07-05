# Archive and Extend Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

The purpose of this script is to perform all extended retentions and archive runs on the correct day of week, month, year, etc. Set your protection policy to perform the **base schedule** (e.g. daily) **local backup only**, and allow the script to handle all weekly, monthly, yearly extended retentions and archive runs. Schedule the script to run daily, and it will identify any existing backups that should have their local retention extended or should be archived.

Note that when compound archive retention is desired, it is **strongly recommended** to archive daily, weekly, monthly archives to **separate external targets**, so that archive expiration of short-term archives won't be dependent on expiration of long-term archives.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'archiveAndExtend'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/run-$scriptName.ps1").content | Out-File "run-$scriptName.ps1"; (Get-Content "run-$scriptName.ps1") | Set-Content "run-$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* archiveAndExtend.ps1: the main powershell script
* run-archiveAndExtend.ps1: launch wrapper
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what would be extended / archived.

```powershell
./archiveAndExtend.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -policyNames 'my policy', 'another policy' `
                       -archiveDaily 5 `
                       -dailyVault myDailyTarget `
                       -keepWeekly 31 `
                       -archiveWeekly 31 `
                       -weeklyVault myWeeklyTarget `
                       -dayOfWeek Sunday `
                       -keepMonthly 90 `
                       -archiveMonthly 180 `
                       -monthlyVault myMonthlyTarget `
                       -dayOfMonth -1 `
                       -keepQuarterly 180 `
                       -archiveQuarterly 365 `
                       -quarterlyVault myQuarterlyVault `
                       -quarterlyDates '04-07', '07-01' `
                       -keepYearly 180 `
                       -archiveYearly 3650 `
                       -yearlyVault myYearlyVault `
                       -dayOfYear -1 `
                       -keepSpecial 180 `
                       -archiveSpecial 3650 `
                       -specialVault mySpecialVault `
                       -specialDates '03-21', '07-21' `
                       -commit
```

Then, if you're happy with the list of snapshots that will be processed, run the script again and include the -commit switch. This will execute the archive tasks.

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -newerThan: (optional) Process backups no older than x days (default is 2)
* -archiveDaily: (optional) days to retain daily archives
* -dailyVault: (optional) external target for daily archives
* -dayOfWeek: (optional) day of Week for weekly snapshot (e.g. Sunday)
* -keepWeekly: (optional) days to retain weekly snapshots
* -archiveWeekly: (optional) days to retain weekly archives
* -weeklyVault: (optional) external target for weekly archives
* -dayOfMonth: (optional) day of month for monthly snapshot (1 = 1st day of month, -1 = last day of month)
* -keepMonthly: (optional) days to retain monthly snapshots
* -archiveMonthly: (optional) days to retain monthly archives
* -monthlyVault: (optional) external target for monthly archives
* -quarterlyDates: (optional) list of quarterly dates (e.g. '04-01', '07-01')
* -keepQuarterly: (optional) days to retain monthly snapshots
* -archiveQuarterly: (optional) days to retain monthly archives
* -quarterlyVault: (optional) external target for monthly archives
* -dayOfYear: (optional) day of year for yearly snapshot (1 = Jan 1, -1 = Dec 31)
* -keepYearly: (optional) days to retain yearly snapshots
* -archiveYearly: (optional) days to retain yearly archives
* -yearlyVault: (optional) external target for yearly archives
* -specialDates: (optional) list of special dates (e.g. '03-21', '09-21')
* -keepSpecial: (optional) days to retain special snapshots
* -archiveSpecial: (optional) days to retain special archives
* -specialVault: (optional) external target for special archives
* -commit: (optional) test run only if omitted
