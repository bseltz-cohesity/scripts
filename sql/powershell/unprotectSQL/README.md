# Unprotect SQL Databases, Instances or Servers using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script removes a database, instance or server from the selections of an existing SQL server protection group. If the item being removed is not itself explicitly selected but is auto-protected because a parent entity (its instance or server) is selected, the script adds an exclusion filter instead, since there is no explicit selection to remove. If a server or instance is removed and it isn't itself explicitly selected, any of its child instances or databases that are explicitly selected are unselected instead.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectSQL'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectSQL.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/unprotectSQL/unprotectSQL.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# remove an entire server
./unprotectSQL.ps1 -vip mycluster `
                    -username myuser `
                    -domain mydomain.net `
                    -jobName 'my sql job' `
                    -serverName sqlserver1

# remove an instance
./unprotectSQL.ps1 -vip mycluster `
                    -username myuser `
                    -domain mydomain.net `
                    -jobName 'my sql job' `
                    -serverName sqlserver1 `
                    -instanceName SQLInstance1

# remove one or more databases
./unprotectSQL.ps1 -vip mycluster `
                    -username myuser `
                    -domain mydomain.net `
                    -jobName 'my sql job' `
                    -serverName sqlserver1 `
                    -instanceName SQLInstance1 `
                    -dbName db1, db2
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

* -jobName: (required) name of the SQL protection group to modify
* -serverName: (required, unless -serverList is used) one or more server names to unprotect (comma separated)
* -serverList: (optional) text file of server names (one per line)
* -instanceName: (optional) one or more instance names, scoped to each server above (comma separated)
* -dbName: (optional) one or more database names to unprotect, scoped to each instance above (comma separated)
* -dbList: (optional) text file of database names (one per line)

If -dbName/-dbList is omitted, -instanceName specifies whole instances to unprotect. If both -instanceName and -dbName/-dbList are omitted, -serverName specifies whole servers to unprotect. If -dbName/-dbList is used without -instanceName, the instance defaults to MSSQLSERVER.

## Removal Behavior

For each specified server, instance or database, the script checks whether it (or a parent of it) is explicitly selected in the job:

* If the item itself is explicitly selected, it is removed from the selection. Removing a server or instance also unselects any of its children that were explicitly selected.
* If the item is not itself selected, but is being backed up only because a parent (its instance or server) is explicitly selected, an exclusion filter is added instead (server/instance/ for an instance, server/instance/database for a database), since auto-protected items have no explicit selection to remove.
* If a server or instance is not itself selected, but has children that are explicitly selected, those children are unselected.
* If the item isn't protected by the job at all, no change is made and a warning is displayed.

Exclusion filters are case sensitive, so the script always builds them from the exact names registered on the Cohesity cluster rather than the casing typed on the command line.
