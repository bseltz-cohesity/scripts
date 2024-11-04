# Cohesity REST API PowerShell Example - Refresh a Protection Source

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform a refresh operation on a protection source. The prime example of where this is useful is if a new virtual machine is created on VMware (or other hypervisor) and you want Cohesity to recognize the new VM. Refresh is automatic on a schedule, but a manual refresh can be executed to speed up the process.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'refreshSource'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [refreshSource.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/refreshSource/refreshSource.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./refreshSource.ps1 -vip mycluster `
                    -username myuser `
                    -domain mydomain.net `
                    -sourceName server1.mydomain.net, server2.mydomain.net
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key as password
* -password: (optional) will prompt or use stored password if omitted
* -sourceName: one or more source names to refresh (comma separated)
