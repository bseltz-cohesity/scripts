# Unprotect an Object using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script removes objects from protection groups.

Note: If the object is the last remaining object in a protection group, the group will be deleted.

Warning: This script has not been tested on every type of protection group and with every permutation of object selections. Please test using a test object/group to ensure correct behavior. If incorrect behavior is noticed, please open an issue on GitHub.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectObjects'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectObjects.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectObjects/unprotectObjects.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./unprotectObjects.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -objectName myserver.mydomain.net `
                       -jobName myjob
```

Note: server names must exactly match what is shown in protection sources.

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

* -objectName: (optional) comma separated list of object names to remove from jobs
* -objectList: (optional) text file containing object names to remove from jobs (one per line)
* -jobName: (optional) comma separated list of job names to remove objects from
* -jobList: (optional) text file containing job names to remove objects from (one per line)
