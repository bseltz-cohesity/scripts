# Cohesity REST API Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

Provided here are some rudimentary examples to provide understanding of basic principles of Cohesity API authentication and access. These examples use PowerShell's Invoke-RestMethod commandlet (cohesity-api.ps1 uses these same techniques under the covers).

## Download these example scripta

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'accessToken'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/rudiments/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'userSession'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/rudiments/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'webSession'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/rudiments/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'apiKey'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/rudiments/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'helios'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/rudiments/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Rudimentary Authentication Examples for PowerShell

* [accessToken.ps1](accessToken.ps1): authenticate to a Cohesity cluster using the v1 accessTokens API
* [userSession.ps1](userSession.ps1): authenticate to a Cohesity cluster using the v2 users/sessions API
* [webSession.ps1](webSession.ps1): authenticate to a Cohesity cluster using the UI /login API
* [apiKey.ps1](apiKey.ps1): authenticate to a Cohesity cluster using an API key
* [helios.ps1](helios.ps1): authenticate through Helios to a Cohesity cluster using an API key
