# List and Cleanup Deleted Protection Groups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell lists and cleans up deleted protection groups.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deletedProtectionGroups'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deletedProtectionGroups.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/deletedProtectionGroups/deletedProtectionGroups.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so. To list all deleted protection groups:

```powershell
./deletedProtectionGroups.ps1 -vip mycluster `
                              -username myuser `
                              -domain mydomain.net
```

To expire the snapshots and completely remove the deleted protection groups:

```powershell
./deletedProtectionGroups.ps1 -vip mycluster `
                              -username myuser `
                              -domain mydomain.net `
                              -deleteSnapshots
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

* -jobName: (optional) one or more job names to include (comma separated)
* -jobList: (optional) text file of job names to include (one per line)
* -deleteSnapshots: (optional) azureSourceName: name of registered azure protection source

Note: by default, all deleted jobs are listed/removed unless you specify using the -jobName or -jobList parameters.
