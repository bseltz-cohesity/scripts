# Exclude VMs from Protection by vSphere Tag using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script excludes VMs from protection jobs by vSphere tag.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'excludeVMsByTag'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [excludeVMsByTag.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/excludeVMsByTag/excludeVMsByTag.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
# example
./excludeVMsByTag.ps1 -vip mycluster -username myusername -domain mydomain.net -tag 'DoNotBackup' -vCenterName myvcenter.mydomain.net
# end
```

```text
Connected!
Excluding DoNotBackup from Prod VMs
Excluding DoNotBackup from Dev VMs
Excluding DoNotBackup from Test VMs
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -jobName: (optional) exclude from a specific job. If omitted, will exclude from all VM jobs
* -tag: vSphere tag to exclude from the job(s)
