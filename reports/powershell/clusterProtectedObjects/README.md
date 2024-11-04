# List Protected Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists protected object (objects where protection runs have occurred) in Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'clusterProtectedObjects'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [clusterProtectedObjects.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/clusterProtectedObjects/clusterProtectedObjects.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
# example
./clusterProtectedObjects.ps1 -vip mycluster -username myusername -domain mydomain.net
# end example
```

## Authentication Parameters

* -vip: one or more names or IPs of Cohesity clusters (comma separated)
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -days: (optional) limit recovery point query to the last X days
* -numRuns: (optional) runs API paging (default is 120)
* -pageSize: (optional) recovery API paging (default is 1000)
* -environment: (optional) one or more types (comma separated) to include in query (e.g. kSQL, kVMware)
* -excludeEnvironment: (optional) one or more types (comma seaparated) to exclude from query  (e.g. kSQL, kVMware)
* -ouputPath: (optional) path to write output file (default is '.')
* -includeLogs: (optional) include log backups in backup counts
