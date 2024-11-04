# Unprotect Missing VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script updates VMware protection jobs to remove missing VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'unprotectMissingVMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [unprotectMissingVMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectMissingVMs/unprotectMissingVMs.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To update all VMware protection jobs:

```powershell
./unprotectMissingVMs.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -commit
```

To operate on specific jobs, you can use the -jobName and or -jobList parameters

```powershell
./unprotectMissingVMs.ps1 -vip mycluster `
                          -username myusername `
                          -domain mydomain.net `
                          -jobName 'My Job1', 'My Job 2' `
                          -jobList ./myjoblist.txt `
                          -commit
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -jobName: (optional) one or more job names (comma separated)
* -jobList: (optional) text file containing job names (one per line)
* -commit: (optional) update the jobs (default is test mode only)
