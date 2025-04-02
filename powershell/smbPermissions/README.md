# Set Share Permissions on a View or Share using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script sets SMB share permissions on a view or share.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'smbPermissions'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [smbPermissions.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/smbPermissions/smbPermissions.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./smbPermissions.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -shareName myshare `
                     -readWrite mydomain.net\user1 `
                     -fullControl mydomain.net\admingroup1, mydomain.net\admingroup2 `
                     -remove everyone
#end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -shareName: name of view or share
* -fullControl: (optional) comma separated list of principals to grant full control
* -readWrite: (optional) comma separated list of principals to grant read/write access
* -modify: (optional) comma separated list of principals to grant modify access
* -readOnly: (optional) comma separated list of principals to grant read only access
* -superUser: (optional) comma separated list of principals to grant super user access
* -remove: (optional) comma separated list of principals to remove from access
* -reset: (optional) remove all pre-existing permissions - if no principals are specified, Everyone (full control) will be set as the default
