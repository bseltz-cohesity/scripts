# Get My Backup Status using  PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script detects if the specified object is currently being backed up.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'myBackupStatus'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [myBackupStatus.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/myBackupStatus/myBackupStatus.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
# example
./myBackupStatus.py -vip mycluster `
                    -username myuser `
                    -domain mydomain.net ` 
                    -myName vm1 `
                    -wait
# end example
```

If the script detects a current backup run for vm1:

* if the -wait switch was used, the script will monitor the backup to completion and then exit with exit code 0
* -f the -wait switch was not used, the script will exit with exit code1 (backup running)

If the script does not detect a running backup, it will exit with exit code 0

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) impersonate a multitenancy org
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -wait: (optional) wait for backup completion
* -interactive: (optional) allow shorter sleep times and skip cache wait time
* -sleepTimeSecs: (optional) seconds to sleep between status queries (default is 360)
* -cacheWaitTime: (optional) wait for read replica update (default is 60)
* -timeoutSec: (optional) timeout waiting for API response (default is 300)
