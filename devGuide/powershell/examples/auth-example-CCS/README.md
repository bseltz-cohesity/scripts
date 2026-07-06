# Authentication Example for CCS in PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script provides the command line options and functions to authenticate to Cohesity Cloud Protection Service, using API key authentication.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'auth-example-CCS'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/examples/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* auth-example-CCS.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

## Examples

### Connect through Helios

The default vip is helios.cohesity.com. Use the short cluster name (as registered in Helios).

```powershell
./auth-example-CCS.ps1 -objectName myVM
```

### Connect through Helios as a specific user

```powershell
./auth-example-CCS.ps1 -username myuser@mydomain.net -objectName myVM
```

The username is not used for authentication, but it is used to store/retrieve the cached API key

## Authentication Parameters

* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password

## Other Parameters

* -objectName: name of object to search for (e.g. name of VM)
