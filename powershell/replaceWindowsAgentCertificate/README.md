# Replace Windows Agent Certificate using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell replaces the Cohesity agent certificate on a Windows host.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'replaceWindowsAgentCertificate'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Components

* [replaceWindowsAgentCertificate.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/replaceWindowsAgentCertificate/replaceWindowsAgentCertificate.ps1): the main powershell script

## Examples

```powershell
./replaceWindowsAgentCertificate.ps1 -serverName myserver.mydomain.net
```

## Parameters

* -serverName: server to process
* -certFile: (optional) default is server_cert-**_serverName_**
