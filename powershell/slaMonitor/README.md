# Monitor Missed SLAs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script finds missed SLAs for recent job runs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'slaMonitor'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [slaMonitor.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/slaMonitor/slaMonitor.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To monitor all clusters through Helios:

```powershell
./slaMonitor.ps1 -username myuser `
                 -maxLogBackupMinutes 15 `
                 -smtpServer smtp.mydomain.net `
                 -sendTo myuser@mydomain.net `
                 -sendFrom someuser@mydomain.net
```

Or to monitor specific Helios clusters:

```powershell
./slaMonitor.ps1 -username myuser `
                 -clusterName mycluster1, mycluster2 `
                 -maxLogBackupMinutes 15 `
                 -smtpServer smtp.mydomain.net `
                 -sendTo myuser@mydomain.net `
                 -sendFrom someuser@mydomain.net
```

To connect directly to one or more clusters:

```powershell
./slaMonitor.ps1 -vip mycluster1, mycluster2 `
                 -username myusername `
                 -domain mydomain.net `
                 -maxLogBackupMinutes 15 `
                 -smtpServer smtp.mydomain.net `
                 -sendTo myuser@mydomain.net `
                 -sendFrom someuser@mydomain.net
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -daysBack: (optional) skip finished runs older than X days (default is 7)
* -maxLogBackupMinutes: (optional) alert log backups ran/running longer than X minutes
* -runningOnly: (optional) only report on runs that are still running
* -logsOnly: (optional)  only report on log backups
* -environment: (optional) only report on specific environment (e.g. -environment kSQL)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendFrom: (optional) email address to show in the from field
