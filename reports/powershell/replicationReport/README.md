# Report Replication Stats Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates a report of replication stats, per object, per run, and per day.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'replicationReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [replicationReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/replicationReport/replicationReport.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script, using a local account to authenticate:

```powershell
./replicationReport.ps1 -vip mycluster `
                        -username admin `
                        -domain local
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) one or more job names to inspect (comma separated)
* -jobList: (optional) text file of job names to inspect (one per line)
* -environment: (optional) one or more types (comma separated) to include in query (e.g. kSQL, kVMware)
* -excludeEnvironment: (optional) one or more types (comma seaparated) to exclude from query  (e.g. kSQL, kVMware)
* -unit: (optional) display sizes in GiB or MiB (default is MiB)
* -daysBack: (optional) number of days back to inspect (default is 7)
* -numRuns: (optional) page size for retrieving runs (default is 100)
* -ouputPath: (optional) path to write output file (default is '.')
