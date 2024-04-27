# Gather Sizing Data Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects the logical size, data read and written over time of protected objects. Output is written to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'detailedActivityReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [detailedActivityReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/detailedActivityReport/detailedActivityReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./detailedActivityReport.ps1 -vip mycluster `
                             -username myuser `
                             -domain mydomain.net `
                             -unit MiB
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) password or API key (will use stored password by default)
* -mfaCode: (optional) multi-factor authentication code
* -emailMfaCode: (optional) send mfaCode via email
* -daysBack: (optional) number of days to inspect (default is 31)
* -unit: (optional) MiB or GiB (default is MiB)
* -numRuns: (optional) number of runs to grab at a time (default is 100)
* -indexStats: (optional) collect indexing task durations

## Definitions

* Data Read: The amount of data read over the network (from the source to Cohesity) during the backups.
* Data Written: The data read, reduced by deduplication and compression, that is written to disk.
* Logical: the size of the object as reported by the source (e.g. a 10 GiB VM)
* Peak Read: the maximum daily data read for the days that were collected
* Last Day Read: the most recent daily data read
* Read Over Days: the sum of the daily data read for the days that were collected
* Avg Read: the average of the daily data read for the days that were collected
* Last Data Written: the most recent daily data written
* Written Over Days: sum of daily data written for the days that were collected
* Avg Data Written: the average data written for the days that were collected
* Days Collected: the number of days that were collected
* Daily Read Change Rate: average data read / logical (expressed as a percentage)
* Daily Write Change Rate: average data written / logical (expressed as a percentage)
* Avg Replica Queue Hours: average hours replica tasks waited in queue
* Avg Replica Hours: average hours replica tasks were running
* Avg Logical Replcated: average data transferred pre-dedup
* Avg Physical Replicated: average data transferred post-dedup
* Avg Index Hours: average hours indexing tasks were running
