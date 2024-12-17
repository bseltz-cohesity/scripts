# List Available GFlags using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists available gflags for the specified service.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'gflagList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [gflagList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/gflagList/gflagList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

To get the current list of available gflags for a service:

```powershell
./gflagList.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net `
                -serviceName magneto
```

## Authentication Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity cluster
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email

## Other Parameters

* -serviceName: name of service to retrieve available gflags
