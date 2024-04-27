# Recover a NAS Share using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a protected NAS share to a Cohesity View.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoverNas'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [recoverNas.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/recoverNas/recoverNas.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then run the script like so:

```powershell
./recoverNas.ps1 -vip mycluster `
                 -username admin `
                 -shareName \\netapp1.mydomain.net\share1 `
                 -viewName share1
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -shareName: name of protected NAS share to be recovered
* -viewName: name of Cohesity view to recover to
* -sourceName: (optional) name of protected NAS source

## Optional Parameters

* -fullControl: list of users to grant full control for share permissions (comma separated)
* -readWrite: list of users to grant read/write for share permissions (comma separated)
* -readOnly: list of users to grant read-only for share permissions (comma separated)
* -modify: list of users to grant modify for share permissions (comma separated)
* -smbOnly: set protocol access to SMB only
