# Manage Cluster Services using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script starts, stops and restarts cluster services.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'serviceManager'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [serviceManager.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/serviceManager/serviceManager.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the main script like so:

To list the status of all cluster services:

```powershell
./serviceManager.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net
```

To restart a service:

```powershell
./serviceManager.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -serviceNames kGroot `
                     -restart
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
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -serviceNames: (optional) one or more service names (comma separated)
* -stop: (optional) stop service(s)
* -start: (optional) start service(s)
* -restart: (optional) restart service(s)
* -nowait: (optional) exit immediately (will wait for completion if omitted)
* -sleepSecs: (optional) query for completion every X seconds (default is 10)
