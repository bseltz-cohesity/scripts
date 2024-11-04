# Register AD Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script registers physical servers as Active Directory sources.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerADSource'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerADSource.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/registerADSource/registerADSource.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

Place the files in a folder together and then run the script like so:

```powershell
./registerADSource.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -serverName myDC1.mydomain.net, myDC2.mydomain.net 
```

Or optionally create a text file called servers.txt and populate with the servers that you want to register (one per line), and then run the script like so:

```powershell
./registerADSource.ps1 -vip mycluster `
                       -username myuser `
                       -domain mydomain.net `
                       -serverList ./servers.txt 
```

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

* -serverName: name of a single server to add to the job
* -serverList: a text file list of servers to add to the job
