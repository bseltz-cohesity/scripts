# Register New Physical Protection Source using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers new physical host(s) as a Cohesity protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerPhysical'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerPhysical.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/registerPhysical/registerPhysical.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then run the script like so.

```powershell
./registerPhysical.ps1 -vip mycluster -username myusername -domain mydomain.net -serverName w2016.mydomin.net
```

or if you want to register a list of servers:

```powershell
./registerPhysical.ps1 -vip mycluster -username myusername -domain mydomain.net -serverList ./servers.txt
```

Note that the Cohesity agent must be installed on the host and that firewall port 50051/tcp on the host must be accessible by the Cohesity cluster.

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

## Other Parameters

* -serverName: (optional) name of server to register
* -serverList: (optional) text file containing list of servers to register (one per line)
* -force: (optional) force register
* -reRegister: (optional) re-register server
