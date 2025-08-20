# Onboard SSO Users and Groups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds or removes SSO domain Users and Groups from Access Management, and can also generate an API key for a user.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory.

```powershell
# Download Commands
$scriptName = 'onboardSSOUser'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [onboardSSOUser.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/onboardSSOUser/onboardSSOUser.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

## Examples

To add a user or group:

```powershell
./onboardSSOUser.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -principalName mySSOuser `
                     -ssoDomain mydomain.net `
                     -role operator, viewer
```

To remove a user:

```powershell
./onboardSSOUser.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -principalName mySSOuser `
                     -ssoDomain mydomain.net `
                     -remove
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -ssoDomain: SSO domain FQDN
* -principalName: (optional) one or more user/group names (comma separated)
* -principalList: (optional) text file of user/group names (one per line)
* -role: (optional) one or more role names/labels (comma separated)
* -remove: (optional) remove the specified user/group
* -generateApiKey: (optional) generate new API key for user (not applicable for groups)

## Authenticating to Helios

The Test/Wrapper scripts can be configured to log onto clusters directly, or log onto Helios.

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
