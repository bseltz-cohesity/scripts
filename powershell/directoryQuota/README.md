# Set a Directory Quota using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script sets a quota on a directory within a Cohesity view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'directoryQuota'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* directoryQuota.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

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

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: name of new view where paths are located
* -path: (optional) directory path(s) within view to apply the quota (comma separated)
* -pathList: (optional) text file containing paths to apply the quota (one path per line)
* -quotaLimitGiB: (optional) quota limit in GiB
* -quotaAlertGiB: (optional) alert threshold in GiB
