# Report Logical Size of a Protected View Over Time

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script displays the logical size of a protected view over time.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'logicalSizeGrowth'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [logicalSizeGrowth.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/logicalSizeGrowth/logicalSizeGrowth.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
.\logicalSizeGrowth.ps1 -vip mycluster -username myuser -domain mydomain.net -jobName 'RMAN Dump' -numRuns 7
Connected!

Logical Size History for RMAN Backup

          Date/Time  Size (GB)
          =========  =========

10/3/19 10:40:01 PM  13.97
10/2/19 10:40:00 PM  14.11
10/1/19 10:40:01 PM  16.82
9/30/19 10:40:01 PM  16.74
9/29/19 10:40:00 PM  16.74
9/28/19 10:40:01 PM  13.86
9/27/19 10:40:00 PM  13.85

```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
* -jobName: name of protection job to evaluate
* -numRuns: defaults to 31
