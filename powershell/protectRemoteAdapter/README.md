# Create a Remote Adapter Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a Remote Adapter protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectRemoteAdapter'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectRemoteAdapter.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectRemoteAdapter/protectRemoteAdapter.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./protectRemoteAdapter.ps1 -vip mycluster `
                           -username myuser `
                           -domain mydomain.net `
                           -jobname newRAjob `
                           -viewname RAview `
                           -servername oracle1.mydomain.net `
                           -user oracle `
                           -policyname 'My Policy' `
                           -startTime '23:00' `
                           -scriptPath '/home/oracle/scripts/dbbackup.sh' `
                           -scriptParams 'my params' `
                           -logScriptPath '/home/oracle/scripts/logbackup.sh' `
                           -logScriptParams 'other params'
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

## Basic Parameters

* -jobname: name of protection job to create
* -policyname: (optional) name of protection policy to use for protection job
* -viewname: (optional) name of view to protect

## New Job Parameters

* -timezone: (optional) default is 'America/New_York'
* -starttime: Daily start time of job (e.g. 23:59)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -paused: (optional) pause future runs (new job only)

## Script Parameters

* -servername: (optional) name of remote host to protect
* -serveruser: (optional) name of ssh user on remote host
* -scriptPath: full path to script on remote host (e.g. /home/oracle/rmanscript.sh)
* -scriptParams: (optional) any parameters to be passed to the script
* -logScriptPath: path to log backup script (required only if selected policy is log-enabled)
* -logScriptParams: (optional) any parameters to be passed to the log script
* -fullScriptPath: path to full backup script (required only if selected policy does periodic full)
* -fullScriptParams: (optional) any parameters to be passed to the full backup script
