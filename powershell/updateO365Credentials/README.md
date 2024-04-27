# Update O365 Credentials using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script sets the O365 username/password and app ID/SecretKey for an O365 protection source.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateO365Credentials'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateO365Credentials.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/updateO365Credentials/updateO365Credentials.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
# example
./updateO365Credentials.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -o365source mydomain.onmicrosoft.com `
                            -o365user myO365user@mydomain.onmicrosoft.com `
                            -o365pwd mySecretPassword `
                            -appId abcdef12-3456-7890-abcd-ef1234567890, abcdef12-3456-7890-abcd-ef1234567891 `
                            -appSecretKey 'XZww7Y8TBHFNXaLazj8P-tYihCY/Z1=:', 'ZZww7Y8TBHFNXaLazj8P-tYihCY/Z2=:'
# end example
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) your AD domain (defaults to local)
* -o365source: name of registered O365 source to be updated
* -o365user: name of O365 user
* -o365pwd: password for O365 user
* -appId: One or more App IDs for MS Graph API access (comma separated)
* -appSecretKey: One or more App Secret Keys for MS Graph API access (comma separated)
