# List Clones using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning: This script can delete data

This powershell script displays a list of existing clones (databases and VMs) and optionally tears them down.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'cloneList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [cloneList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneList/cloneList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the main script like so:

```powershell
./cloneList.ps1 -vip mycluster `
                -username myusername `
                -domain mydomain.net
```

## Authentication Parameters

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

## Other Parameters

* -type: (optional) filter by type (sql, oracle, vm, view, appview)
* -olderThan: (optional) filter by create date (defaults to 0 days old)
* -source: (optional) filter by source server, VM or view name
* -sourceDB: (optional) filter by source database (e.g. dbname for Oracle, instance/dbname for SQL)
* -target: (optional) filter by source server, VM or view name
* -targetDB: (optional) filter by source database (e.g. dbname for Oracle, instance/dbname for SQL)
* -taskId: (optional) filter by task ID
* -destroy: (optional) destroy clones that match output list
* -wait: (optional) wait for deletion(s) to complete
