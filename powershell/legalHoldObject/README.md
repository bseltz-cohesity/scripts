# Set Legal Hold on an Object using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script add or remove legal hold for a specified object.

Runs or objects placed on legal hold will not expire when their retention end date is reached. Instead, they will be retained until the legal hold is removed. Note that the user adding or removing legal hold must have the Data Security role assigned to their account.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'legalHoldObject'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [legalHoldObject.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/legalHoldObject/legalHoldObject.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./legalHoldObject.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -jobName 'my job' `
                      -objectName 'myVM' `
                      -addHold

## Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM
* -jobName: (optional) name of the protection job
* -objectName: name of object to place on legal hold
* -latest: (optional) use latest run
* -startDate: (optional) use range of dates starting with (e.g. '2020-10-22')
* -endDate: (optional) use range of dates ending with (e.g. '2020-10-27')
* -days: (optional) number of days back to operate on
* -addHold: (optional) add legal hold
* -removeHold: (optional) remove legal hold
