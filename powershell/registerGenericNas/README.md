# Register Generic NAS Sources using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script registers one or more generic NAS shares as sources on Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerGenericNas'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerGenericNas.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/registerGenericNas/registerGenericNas.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./registerGenericNas.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -mountPoint '\\myserver\myshare1', '\\myserver\myshare2' ` 
                         -smbUserName mydomain.net\myusername
```

or you can use a text file of shares:

```powershell
./registerGenericNas.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -mountList ./myshares.txt `
                         -smbUserName mydomain.net\myusername
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

## Other Parameters

* -mountPoint: (optional) nas mount points to register (comma separated)
* -mountList: (optional) text file containing list of mount points to register (one per line)
* -smbUserName: (optional) SMB username to connect to SMB shares, e.g. mydomain\myusername
* -smbPassword: (optional) SMB password to connect to SMB shares (will be prompted if necessary)
