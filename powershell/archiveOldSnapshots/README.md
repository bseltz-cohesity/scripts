# Archive Old Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script archives local snapshots. This is useful if you have created an archive target (e.g. AWS S3) and want to programatically archive existing local snapshots.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'archiveOldSnapshots'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [archiveOldSnapshots.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/archiveOldSnapshots/archiveOldSnapshots.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -archive switch to see what would be archived.

```powershell
./archiveOldSnapshots.ps1 -vip mycluster `
                          -username myuser `
                          -domain mydomain.net `
                          -vault s3 `
                          -jobNames 'SQL Backup', 'NAS Backup' `
                          -keepFor 365
```

Then, if you're happy with the list of snapshots that will be archived, run the script again and include the -archive switch. This will execute the archive tasks

```powershell
./archiveOldSnapshots.ps1 -vip mycluster `
                          -username myuser `
                          -domain mydomain.net `
                          -vault s3 `
                          -jobNames 'SQL Backup', 'NAS Backup' `
                          -keepFor 365 `
                          -archive `
                          -includeLogs
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

* -vault: Name of archive target
* -jobName: (optional) One or more job names to archive (comma separated)
* -jobList: (optional) text file of job names (one per line)
* -keepFor: (optional) keep archive for X days (from original backup date)
* -ifExpiringAfter: (optional) skip if local snapshot set to expire in X or less days
* -olderThan: (optional) skip if local snapshot is newer than X days
* -archive: (optional) if excluded script will only report what it would do (test run mode)
* -fullOnly: (optional) only archive full backups
* -includeLogs: (optional) also archive log backups (default is to only archive full and incremental backups)
* -dates: (optional) one or more dates to archive, comma separated (e.g. 2021-04-23, 2021-04-24)
* -vaultType: (optional) kCloud, kTape or kNas (default is kCloud)

To monitor the archive tasks, see the script 'monitorArchiveTasks'

## Running and Scheduling PowerShell Scripts

For additional help running and scheduling Cohesity PowerShell scripts, please see <https://github.com/cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
