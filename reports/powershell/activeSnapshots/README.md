# List Active Snapshot Counts Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists the active snapshot count for every protected object in Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'activeSnapshots'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [activeSnapshots.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/activeSnapshots/activeSnapshots.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./activeSnapshots.ps1 -vip mycluster -username myusername -domain mydomain.net
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -days: (optional) limit query to the last X days
* -pageSize: (optional) API paging (default is 500)
* -environment: (optional) one or more types (comma separated) to include in query (e.g. kSQL, kVMware)
* -excludeEnvironment: (optional) one or more types (comma seaparated) to exclude from query  (e.g. kSQL, kVMware)
* -ouputPath: (optional) path to write output file (default is '.')
* -localOnly: (optional) include only local protection groups
* -shortOnly: (optional) only show objects that have fewer snapshots than -days

## Email Parameters

* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
