# Restore MongoDB using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores MongoDB databases/collections

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreMongoDB'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreMongoDB.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreMongoDB/restoreMongoDB.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

To restore a database/collection and overwrite the original:

```powershell
./restoreMongoDB.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net ` 
                     -sourceServer mongodb1.mydomain.net:27017 `
                     -sourceObject customers.notes `
                     -overwrite `
                     -wait
```

Or to restore to an alternate MongoDB server:

```powershell
./restoreMongoDB.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net ` 
                     -sourceServer mongodb1.mydomain.net:27017 `
                     -sourceObject customers.notes `
                     -targetServer mongodb2.mydomain.net:27017 `
                     -suffix '-restore' `
                     -wait
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Required Parameters

* -sourceServer: source server to restore from
* -sourceObject: source database/collection to restore

## Optional Parameters

* -targetServer: (optional) target server to restore to (defaults to source server)
* -recoverDate: (optional) recover from snapshot on or before this date (e.g. '2022-09-21 23:00:00')
* -streams: (optional) number of cuncurrency streams (defaul is 16)
* -suffix: (optional) suffix to apply to recovered object name (e.g. '-restore')
* -overwrite: (optional) overwrite existing object
* -wait: (optional) wait for completion and report status
