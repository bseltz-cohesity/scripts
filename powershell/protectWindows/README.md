# Protect Physical Windows Hosts using PowerShell V2 (6.5.1 and later)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds physical Windows servers to a file-based protection job.

This script is compatible with Cohesity 6.5.1 and later.

**Warning:** The script will overwrite existing exclusions of a server if the server is included in the list of servers to process.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectWindows'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectWindows.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectWindows/protectWindows.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so (you can also specify servers on the command line):

```text
server1.mydomain.net
server2.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Next optionally create a text file called exclusions.txt and populate with the folder paths that you want excluded from every server in the job, like so (you can also specify exclusions on the command line):

```text
*:\DATA01\MSSQL\DATA
C:\TEMP
*.mdf
*:\LOGS01\MSSQL\TRANS_LOGS
```

Then, run the main script like so:

```powershell
./protectWindows.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -servers server1.mydomain.net, server2.mydomain.net `
                     -jobName 'File-based Windows Job' `
                     -exclusions 'c:\windows', 'e:\excluded', 'c:\temp' `
                     -serverList .\serverlist.txt `
                     -exclusionList .\exclusions.txt `
                     -allDrives `
                     -skipNestedMountPoints
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -servers: (optional) one or more servers (comma separated) to add to the proctection job
* -serverList: (optional) file containing list of servers (one per line)
* -jobName: name of protection job
* -inclusions: (optional) inclusion paths (comma separated)
* -inclusionList: (optional) a text file list of paths to include (one per line)
* -exclusions: (optional) one or more exclusion paths (comma separated)
* -exclusionList: (optional) a text file list of exclusion paths (one per line)
* -metadataFile: (optional) path to directive file (e.g. c:\directive.txt)
* -allDrives: (optional) include all drives in the inclusion list
* -skipNestedMountPoints: (optional) if omitted, nested mount points will not be skipped
* -followNasLinks: (optional) if omitted, NAS symlinks will not be followed
* -replaceRules: (optional) if ommited, inclusions/exclusions are appended to existing server rules (if any)
* -allServers: (optional) inclusions/exclusions are applied to all servers in the job
* -allowParallelRuns: (optional) enable parallel runs

## New Job Parameters

* -policyName: (optional) name of protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -quiesce: (optional) try to quiesce but continue if quiesce fails
* -forceQuiesce: (optional) try to quiesce and fail if quiesce fails
