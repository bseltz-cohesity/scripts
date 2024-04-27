# Set a Directory Quota using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script sets a quota on a directory within a Cohesity view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'directoryQuota'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [directoryQuota.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/directoryQuota/directoryQuota.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To View the directory quotas assigned to directories in a view:

```powershell
#example
./directoryQuota.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -viewName myview
#end example
```

To view the directory quotas assigned to specific directories in a view:

```powershell
#example
./directoryQuota.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -viewName myview `
                     -path /mydir, /mydir2
#end example
```

To set the directory quotas for those directores:

```powershell
#example
./directoryQuota.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -viewName myview `
                     -path /mydir, /mydir2 `
                     -quotaLimitGiB 20 `
                     -quotaAlertGiB 18
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -viewName: name of new view where paths are located
* -path: (optional) directory path(s) within view to apply the quota (comma separated)
* -pathList: (optional) text file containing paths to apply the quota (one path per line)
* -quotaLimitGiB: (optional) quota limit in GiB
* -quotaAlertGiB: (optional) alert threshold in GiB
