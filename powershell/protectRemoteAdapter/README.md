# Create a Remote Adapter Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a Remote Adapter protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectRemoteAdapter'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectRemoteAdapter.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/protectRemoteAdapter/protectRemoteAdapter.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

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

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobname: name of protection job to create
* -viewname: name of view to protect
* -servername: name of remote host to protect
* -user: name of ssh user on remote host
* -policyname: name of protection policy to use for protection job
* -storagedomain: (optional) default is DefaultStorageDomain
* -timezone: (optional) default is 'America/New_York'
* -starttime: Daily start time of job (e.g. 23:59)
* -scriptPath: full path to script on remote host (e.g. /home/oracle/rmanscript.sh)
* -scriptParams: (optional) any parameters to be passed to the script
* -logScriptPath: path to log backup script (required only if selected policy is log-enabled)
* -logScriptParams: (optional) any parameters to be passed to the log script
* -fullScriptPath: path to full backup script (required only if selected policy does periodic full)
* -fullScriptParams: (optional) any parameters to be passed to the full backup script

## Notes

The script will create the view if it does not already exist. This script does not do any host-side setup; it is still required for the user to manage the deployment of the host-side scripts and ssh keys.
