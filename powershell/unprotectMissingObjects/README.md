# Unprotect Missing Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script removes missing objects from protection groups.

Note: If the object is the last remaining object in a protection group, the group will be deleted.

Warning: This script has not been tested on every type of protection group and with every permutation of object selections. Please test using a test object/group to ensure correct behavior. If incorrect behavior is noticed, please open an issue on GitHub.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectMissingObjects'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectMissingObjects.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectMissingObjects/unprotectMissingObjects.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./unprotectMissingObjects.ps1 -vip mycluster `
                              -username myusername `
                              -domain mydomain.net
```

Note: server names must exactly match what is shown in protection sources.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -useApiKey: (optional) use API Key for authentication
* -password: (optional) will use stored password by default
* -jobName: (optional) comma separated list of job names to remove objects from
* -jobList: (optional) text file containing job names to remove objects from
