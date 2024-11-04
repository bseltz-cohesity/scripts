# Clone a Cohesity SMB View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a protected (active or replicated) SMB view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneSMBView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneSMBView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneSMBView/cloneSMBView.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneSMBView.ps1 -vip mycluster `
                   -username admin `
                   -domain local `
                   -viewName SMBShare `
                   -newName Cloned-SMBShare
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

* -viewName: (optional) name of source view to clone
* -newName: name of target view to create
* -vaultName: (optional) name of archive target to clone from
* -backupDate: (optional) date of backup (acceptable formats are 'YYYY/MM/dd' or 'YYYY/MM/dd HH:mm')
* -showDates: (optional) list available backup dates in 'YYYY/MM/dd' format
* -showVersions: (optional) list available backup dates in 'YYYY/MM/dd HH:mm' format
* -deleteView: (optional) delete the view "newView" and exit

## Access Control

* -readOnly: (optional) comma separated list of principals to grant read only access
* -readWrite: (optional) comma separated list of principals to grant read/write access
* -modify: (optional) comma separated list of principals to grant modify access
* -fullControl: (optional) comma separated list of principals to grant full control
* -ips: (optional) comma separated list of ips/subnets to grant network access
