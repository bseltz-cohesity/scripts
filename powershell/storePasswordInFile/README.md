# Store API Password in File Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists the currently active archive tasks, sorted oldest to newest

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storePasswordInFile'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storePasswordInFile.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/storePasswordInFile/storePasswordInFile.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./storePasswordInFile.ps1 -vip mycluster -username myusername -domain mydomain.net -password swordfish
```

## Parameters

* -vip: (optional) the Cohesity cluster to connect to (defaults to helios.cohesity.com)
* -username: (optional) the cohesity user to login with (defaults to 'helios')
* -domain: (optional) domain of the Cohesity user (defaults to local)
* -useApiKey: (optional) store an API key instead of a password
* -password: (optional) password to store (will be prompted if omitted)
