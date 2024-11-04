# Create an NFS View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates an NFS View on Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'createNfsView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [createNfsView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/createNfsView/createNfsView.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./createNfsView.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -viewName mynewview `
                    -readWrite 192.168.1.7/32, 192.168.1.8/32 `
                    -readOnly 192.168.1.0/24 `
                    -rootSquash
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

## Other Parameters

* -viewName: name of new view to create
* -readWrite: (optional) comma separated list of CIDR addresses to grant read/write access (e.g. 192.168.1.7/32)
* -readOnly: (optional) comma separated list of CIDR addresses to grant read/only access (e.g. 192.168.1.0/24)
* -rootSquash: (optional) enable root squash
* -qosPolicy: 'Backup Target Low', 'Backup Target High', 'TestAndDev High', 'TestAndDev Low' (default is 'TestAndDev High')
* -storageDomain: name of storage domain to place view data. Defaults to DefaultStorageDomain
