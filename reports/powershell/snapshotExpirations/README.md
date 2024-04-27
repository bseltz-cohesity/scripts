# Report Snapshot Expiration Dates Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates a report of local snapshots and their expiration dates.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'snapshotExpirations'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [snapshotExpirations.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/snapshotExpirations/snapshotExpirations.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script, using a local account to authenticate:

```powershell
./snapshotExpirations.ps1 -vip mycluster `
                          -username admin `
                          -domain local
```

or to authenticate with an AD account:

```powershell
./snapshotExpirations.ps1 -vip mycluster `
                          -username myuser `
                          -domain mydomain.net
```

## Authentication Parameters

* -vip: one or more names or IPs of Cohesity clusters (comma separated)
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email

## Other Parameters

* -jobName: (optional) one or more job names to inspect (comma separated)
* -jobList: (optional) text file of job names to inspect (one per line)
* -numRuns: (optional) page size per API call (default is 500)
