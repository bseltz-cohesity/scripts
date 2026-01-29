# Enable Datalock on Policies using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script enables Datalock on protection policies.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'enableDatalock'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [enableDatalock.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/enableDatalock/enableDatalock.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To add datalock to all policies, using a user that has the `Data Security` role:

```powershell
./enableDatalock.ps1 -vip mycluster `
                     -username myDSuser `
                     -domain mydomain.net
```

Or, to add datalock to all policies, using a user that has the `Admin` role:

```powershell
./enableDatalock.ps1 -vip mycluster `
                     -username myAdminuser `
                     -domain mydomain.net `
                     -asAdmin
```

To add datalock to a few specific policies:

```powershell
./enableDatalock.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -policyName 'my policy 1', 'my policy 2'
```

To add datsalock to a list of policies provided in a text file:

```powershell
./enableDatalock.ps1 -vip mycluster `
                     -username myuser `
                     -domain mydomain.net `
                     -policyList ./mypolicylist.txt
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

* -policyName: (optional) one or more policy names (comma separated)
* -policyList: (optional) text file of policy names (one per line)
* -lockDuration: (optional) datalock duration in days (default is 5)
* -asAdmin: (optional) see below
* -disable: (optional) remove datalock

## User rights requirements

Setting datalock requires a Cohesity user that is granted the Data Security role. So, by default the script should be run using a user with the role.

If such a user does not exist, the script can be run as an admin, and will create a temporary user with this role to perform the operation. The temporary user will be removed when the operation is complete. If the script will be run using an admin user, use the `-asAdmin` switch.
