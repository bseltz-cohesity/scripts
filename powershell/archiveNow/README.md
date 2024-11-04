# Archive Latest Snapshot using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script archives the latest snapshot of all (or selected) jobs to the specified criteria to an external target.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'archiveNow'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [archiveNow.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/archiveNow/archiveNow.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module [README](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cohesity-api)

Place both files in a folder together, then we can run the script like so:

```powershell
./archiveNow.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobNames 'NAS Backup', 'SQL Backup' `
                        -vault s3 `
                        -keepFor 180 `
                        -commit
```

Connecting via Helios:

```powershell
./archiveNow.ps1 -clusterName mycluster `
                        -jobNames 'NAS Backup', 'SQL Backup' `
                        -vault s3 `
                        -keepFor 180 `
                        -commit
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

* -commit: (optional) execute the archive tasks (default is to show what would happen)
* -keepFor: (optional) number of days (from original backup date) to retain the archive
* -vault: name of external target to archive to
* -vaultType: (optional) type of archive target (kCloud, kTape, kNas - defaults to kCloud)
* -jobName: (optional) one or more job names (comma separated), default is all jobs
* -jobList: (optional) text file of job names (one per line), default is all jobs
* -localOnly: (optional) archive only jobs local to this cluster
* -fullOnly: (optional) only archive full protection runs (not incremental)
* -numRuns: (optional) number of runs to review per job (default is 20)

## Running and Scheduling PowerShell Scripts

For additional help running and scheduling Cohesity PowerShell scripts, please see [Running Cohesity PowerShell Scripts](https://github.com/cohesity/community-automation-samples/blob/main/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf)
