# Create a View Alias using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates a view alias (additional share) in a Cohesity View.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'createViewAlias'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [createViewAlias.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/createViewAlias/createViewAlias.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./createViewAlias.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -viewName myview `
                      -aliasName myalias `
                      -folderPath /folder1
#end example
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
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Basic Parameters

* -viewName: name of new view to create
* -aliasName: name of alias (share name) to create
* -folderPath: (optional) path to share (default is /)

## SMB Share Permissions Parameters

* -fullControl: (optional) list of principals to grant full control (comma separated)
* -readWrite: (optional) list of principals to grant read write (comma separated)
* -readOnly: (optional) list of principals to grant read only (comma separated)
* -modify: (optional) list of principals to grant modify (comma separated)
