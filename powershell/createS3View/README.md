# Create an S3 View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates an S3 View on Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'createS3View'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [createS3View.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/createS3View/createS3View.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./createS3View.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -viewName newview1 `
                   -allowList 192.168.1.0/24, 192.168.2.11/32 `
                   -qosPolicy 'TestAndDev High' `
                   -quotaLimitGB 20 `
                   -quotaAlertGB 18 `
                   -storageDomain mystoragedomain `
                   -showKeys
#end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster
* -username: (optional) name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email

## Other Parameters

* -viewName: name of new view to create
* -qosPolicy: (optional) defaults to 'Backup Target Low' or choose 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low' (default is 'TestAndDev High')
* -storageDomain: (optional) name of storage domain to place view data. Defaults to DefaultStorageDomain
* -quotaLimitGB: (optional) logical quota in GiB
* -quotaAlertGB: (optional) alert threshold in GiB
* -allowList: (optional) one or more CIDR addresses (comma separated) e.g. 192.168.2.0/24, 192.168.2.11/32
* -caseSensitive: (optional) make file names case sensitive
* -showKeys: (optional) display S3 access key and secret key
