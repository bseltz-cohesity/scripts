# Update Job Description Date Suffix using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds a date suffix to all job descriptions.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'updateJobDescriptionDate'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [updateJobDescriptionDate.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/updateJobDescriptionDate/updateJobDescriptionDate.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then run the script like so:

To run against all Helios connected clusters:

```powershell
./updateJobDescriptionDate.ps1 -username myusername@mydomain.net
```

To run against a subset of Helios connected clusters:

```powershell
./updateJobDescriptionDate.ps1 -username myusername@mydomain.net `
                               -clusterName cluster1, cluster2
```

To run directly against one cluster

```powershell
./updateJobDescriptionDate.ps1 -vip mycluster `
                               -username myusername `
                               -domain mydomain.net share1
```

## Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)
