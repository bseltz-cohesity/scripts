# Restore a Univeral Data Adapter Backup Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores a UDA backup.

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreUDA'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreUDA.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreUDA/restoreUDA.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./restoreUDA.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net `
                 -sourceServer myuda1.mydomain.net `
                 -targetServer myuda2.mydomain.net `
                 -logTime '2022-02-20 06:14:38' `
                 -recoveryArgs '--target-dir=/var/lib/pgsql/10/data/' `
                 -wait
```

## Basic Parameters

* -vip: (optional) Cohesity cluster or MCM to connect to (defaults to helios.cohesity.com)
* -username: (optional) Cohesity username (defaults to helios)
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -mcm: (optional) connect via MCM
* -clusterName: (optional) required when connecting through Helios or MCM
* -sourceServer: name of registered UDA source to restore from
* -recoveryArgs: arguments for recovery, e.g. '--target-dir=/var/lib/pgsql/10/data/'

## Additional Parameters

* -objectName: (optional) database names to restore (comma separated)
* -prefix: (optional) prefix to apply to database names
* -targetServer: (optional) Server name to restore to (defaults to same as sourceServer)
* -logTime: (optional) Point in time to replay the logs to during the restore (e.g. '2019-04-10 22:31:05')
* -latest: (optional) Replay the logs to the latest log backup date
* -wait: (optional) Wait for the restore to complete and report end status (e.g. kSuccess)
* -overwrite: (optional) Overwrite warning when writing to original location
* -progress: (optional) display percent complete
* -concurrency: (optional) number of concurrency streams (default is 1)
* -mounts: (optional) number of mounts (default is 1)

## Point in Time Recovery

By default (if both **-latest** and **-logTime** are omitted), the latest full/incremental snapshot time will be used for the restore.

If you want to replay the logs to the very latest available point in time, use the **-latest** parameter, or if you want to replay logs to a specific point in time, use the **-logTime** parameter and specify a date and time in military format like so:

```powershell
-logTime '2019-01-20 23:47:02'
```

Note that when the -logTime parameter is used with databases where no log backups exist, the full/incremental backup that occurred at or before the specified log time will be used. Also note that if a logtime is specified that is newer than the latest log backup, the latest log backup time will be used.
