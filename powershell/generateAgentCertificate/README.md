# Generate a New Agent Certificate using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates a new agent certificate.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'generateAgentCertificate'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [generateAgentCertificate.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/generateAgentCertificate/generateAgentCertificate.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# example
./generateAgentCertificate.ps1 -vip mycluster `
                               -username myuser `
                               -domain mydomain.net `
                               -serverName myserver.mydomain.net
# end example
```

To include multiple subject alternate names, include them, comma separated, in the -serverName parameter:

```powershell
# example
./generateAgentCertificate.ps1 -vip mycluster `
                               -username myuser `
                               -domain mydomain.net `
                               -serverName myserver.mydomain.net, myserver, 192.168.3.100
# end example
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -servername: name of server as is/will be registered in Cohesity (comma separate multiple subject alternate names)
* -country: (optional) country code (default is US)
* -state: (optional) state code (default is CA)
* -city: (optional) city code (default is SN)
* -organization: (optional) organization (default is Cohesity)
* -organizationUnit: (optional) organization unit (default is IT)
* -expiryDays: (optional) number of days until expiration (default is 365)
