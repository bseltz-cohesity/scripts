# Register Univeral Data Adapter Protection Source using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script registers a Universal Data Adapter protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerUDA'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerUDA.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/registerUDA/registerUDA.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To add some exclusions to a job:

```powershell
./registerUDA.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -sourceType 'Other' `
                  -sourceName postgres1.mydomain.net `
                  -scriptDir /opt/cohesity/postgres/scripts `
                  -sourceArgs '--source-name=postgres1.mydomain.net' `
                  -appUsername postgres
```

## Parameters

* -vip: (optional) Cohesity cluster or MCM to connect to (defaults to helios.cohesity.com)
* -username: (optional) Cohesity username (defaults to helios)
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -mcm: (optional) connect via MCM
* -clusterName: (optional) required when connecting through Helios or MCM
* -sourceName: One or more IP or FQDN of protection sources to register (comma separated)
* -sourceType: Type of UDA database (see list below)
* -scriptDir: Location of UDA scripts, e.g. /opt/cohesity/postgres/scripts
* -sourceArgs: (optional) source registration arguments, e.g. '--source-name=postgres1.mydomain.net'
* -mountView: (optional) false if omitted
* -appUsername: (optional) username to connect to app, e.g. postgres
* -appPassword: (optional) will be prompted if omitted

## UDA Source Types

These are the valid UDA source types as of this writing...

* CockroachDB
* DB2
* MySQL
* Other (use this for PostGreSQL and other pre-release plugins)
* SapHana
* SapMaxDB
* SapOracle
* SapSybase
* SapSybaseIQ
* SapASE
