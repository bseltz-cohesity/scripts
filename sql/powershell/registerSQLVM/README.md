# Register VM as SQL Server using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script registers VMs as SQL servers.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'registerSQLVM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/sql/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [registerSQLVM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/powershell/registerSQLVM/registerSQLVM.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Then, run the main script like so:

```powershell
./registerSQLVM.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -vm myvm
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) your AD domain (defaults to local)
* -vm: (optional) one or more vms to register (comma separated)
* -vmList: (optional) text file containing VMs to register (one per line)
* -useAutoDeployAgent: (optional) will use pre-installed agent if omitted
* -vmUser: (optional) windows username for auto deploy (e.g. mydomain.net\myuser)
* -vmPwd: (optional) windows password for auto deploy (will be prompted if omitted)
