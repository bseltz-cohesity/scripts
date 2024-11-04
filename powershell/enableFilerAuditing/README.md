# Enable or Disable Filer Auditing using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script enables/disables audit logging on views and shares.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'enableFilerAuditing'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [enableFilerAuditing.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/enableFilerAuditing/enableFilerAuditing.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then run the script like so. To enable audit logging:

```powershell
./enableFilerAuditing.ps1 -vip mycluster `
                          -username myuser `
                          -domain mydomain.net
```

Or to disable audit logging:

```powershell
./enableFilerAuditing.ps1 -vip mycluster `
                          -username myuser `
                          -domain mydomain.net `
                          -disable
```

## Authentication Parameters

* -vip: name or IP of Cohesity cluster to connect to
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code

## Other Parameters

* -disable: (optional) disables auditing (default is enable)
